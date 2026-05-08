# frozen_string_literal: true

# =============================================================================
# ForecastService
#
# Orchestration service (Facade pattern) that coordinates all steps required
# to produce a Forecast value object for a given address string:
#
#   Step 1 – GeocodingService     : address string  → Location value object
#   Step 2 – Rails.cache check    : zip code        → cached Forecast (or nil)
#   Step 3 – WeatherApiClient     : coordinates     → raw API hash (on miss)
#   Step 4 – build_forecast       : raw hash        → Forecast value object
#   Step 5 – Rails.cache write    : persist Forecast keyed by zip code
#
# Caching strategy:
#   - Cache key   : "forecast/zip/<zip_code>"
#   - TTL         : 30 minutes (CACHE_TTL constant)
#   - Cache store : configured in config/application.rb (:file_store)
#   - Indicator   : Forecast#cached? returns true for cache hits
#   - Scope       : zip-code level, so different addresses with the same zip
#                   share a cached result (matching the assignment requirement).
#
# Design notes:
#   - Single public entry point (.call) keeps the interface minimal.
#   - Each private method has exactly one responsibility (SRP / encapsulation).
#   - ForecastError wraps all upstream failures into a single, UI-friendly
#     exception type so the controller doesn't need to know about geocoding
#     or weather-API specifics.
#
# Decomposition:
#   ForecastService
#     .call(address)             – public factory / entry point
#     #call                      – instance entry point
#     #geocode_address           – delegates to GeocodingService
#     #fetch_forecast_for        – cache-check + dispatch
#     #read_from_cache           – reads Rails.cache by zip key
#     #rebuild_cached_forecast   – wraps cached data in a new Forecast (cached: true)
#     #fetch_and_cache           – calls WeatherApiClient + writes to cache
#     #build_forecast            – maps raw API hash → Forecast
#     #build_extended_forecast   – maps daily arrays → Array<DailyForecast>
#     #write_to_cache            – persists Forecast to Rails.cache
#     #cache_key                 – constructs the namespaced cache key string
# =============================================================================
class ForecastService
  # Cache TTL matches the assignment requirement: 30 minutes per zip code
  CACHE_TTL               = 30.minutes
  LAST_KNOWN_FORECAST_TTL = 24.hours
  CACHE_KEY_PREFIX        = 'forecast/zip'
  LAST_KNOWN_KEY_PREFIX   = 'forecast/last_known/zip'

  # ---------------------------------------------------------------------------
  # Custom Exceptions
  # ---------------------------------------------------------------------------

  # Single exception type surfaced to the controller; wraps all upstream errors
  class ForecastError < StandardError; end

  # ---------------------------------------------------------------------------
  # Public Interface
  # ---------------------------------------------------------------------------

  # Convenience factory so callers write ForecastService.call(address).
  #
  # @param address [String] raw address string entered by the user
  # @return [Forecast]
  # @raise [ForecastError] on geocoding or weather-API failure
  def self.call(address)
    new(address).call
  end

  # @param address [String]
  def initialize(address)
    @address = address.to_s.strip
  end

  # @return [Forecast]
  def call
    location = geocode_address
    fetch_forecast_for(location)
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  private

  # Converts the raw address string into a Location.
  # Translates GeocodingService exceptions into ForecastError.
  #
  # @return [Location]
  def geocode_address
    GeocodingService.call(@address)
  rescue GeocodingService::AddressNotFoundError => e
    raise ForecastError, e.message
  rescue GeocodingService::GeocodingError => e
    raise ForecastError, "Unable to geocode address: #{e.message}"
  end

  # Checks the cache first; falls through to the API on a miss.
  #
  # @param location [Location]
  # @return [Forecast]
  def fetch_forecast_for(location)
    cached = read_from_cache(location.zip_code)
    if cached
      log_info('forecast.cache_hit', zip_code: location.zip_code)
      return rebuild_cached_forecast(cached, location)
    end

    log_info('forecast.cache_miss', zip_code: location.zip_code)

    fetch_and_cache(location)
  end

  # Reads a previously stored Forecast from Rails.cache.
  #
  # Returns nil when the zip code is blank or the key has expired.
  #
  # @param zip_code [String, nil]
  # @return [Forecast, nil]
  def read_from_cache(zip_code)
    return nil if zip_code.blank?

    Rails.cache.read(cache_key(zip_code))
  end

  # Wraps a cache-hit payload in a new Forecast with cached: true.
  # The location is refreshed from the current request so the display_name
  # reflects exactly what the user typed.
  #
  # @param cached_forecast [Forecast]
  # @param location        [Location]
  # @return [Forecast]
  def rebuild_cached_forecast(cached_forecast, location)
    Forecast.new(
      location:          location,
      current_temp:      cached_forecast.current_temp,
      feels_like:        cached_forecast.feels_like,
      high_temp:         cached_forecast.high_temp,
      low_temp:          cached_forecast.low_temp,
      condition:         cached_forecast.condition,
      extended_forecast: cached_forecast.extended_forecast,
      cached:            true,
      stale:             false
    )
  end

  # Calls the weather API, builds a Forecast, and persists it to the cache.
  #
  # @param location [Location]
  # @return [Forecast]
  def fetch_and_cache(location)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    raw_data = WeatherApiClient.fetch_forecast(
      latitude:  location.latitude,
      longitude: location.longitude
    )

    forecast = build_forecast(location, raw_data)
    write_to_cache(location.zip_code, forecast)
    write_last_known(location.zip_code, forecast)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    log_info('forecast.fetched', zip_code: location.zip_code, duration_ms: duration_ms)
    forecast
  rescue WeatherApiClient::WeatherApiError => e
    stale = read_last_known(location.zip_code)
    if stale
      log_info('forecast.stale_fallback', zip_code: location.zip_code, reason: e.message)
      return rebuild_stale_forecast(stale, location)
    end

    raise ForecastError, "Unable to retrieve weather data: #{e.message}"
  end

  # Returns a stale forecast when the live API fails but we still have a
  # previously successful result persisted under the last-known key.
  #
  # @param stale_forecast [Forecast]
  # @param location [Location]
  # @return [Forecast]
  def rebuild_stale_forecast(stale_forecast, location)
    Forecast.new(
      location:          location,
      current_temp:      stale_forecast.current_temp,
      feels_like:        stale_forecast.feels_like,
      high_temp:         stale_forecast.high_temp,
      low_temp:          stale_forecast.low_temp,
      condition:         stale_forecast.condition,
      extended_forecast: stale_forecast.extended_forecast,
      cached:            true,
      stale:             true
    )
  end

  # Maps raw Open-Meteo JSON to a Forecast value object.
  #
  # @param location [Location]
  # @param raw_data [Hash]   parsed Open-Meteo response
  # @return [Forecast]
  def build_forecast(location, raw_data)
    current = raw_data['current'] || {}
    daily   = raw_data['daily']   || {}

    Forecast.new(
      location:          location,
      current_temp:      current['temperature_2m'],
      feels_like:        current['apparent_temperature'],
      high_temp:         daily.dig('temperature_2m_max', 0),
      low_temp:          daily.dig('temperature_2m_min', 0),
      condition:         WmoWeatherCodeMapper.description(current['weathercode']),
      extended_forecast: build_extended_forecast(daily),
      cached:            false
    )
  end

  # Builds the 6-day extended forecast array from the Open-Meteo daily arrays.
  # Index 0 is today (already represented in current conditions) so we skip it.
  #
  # @param daily [Hash] 'daily' sub-hash from the Open-Meteo response
  # @return [Array<DailyForecast>]
  def build_extended_forecast(daily)
    dates = daily['time']               || []
    highs = daily['temperature_2m_max'] || []
    lows  = daily['temperature_2m_min'] || []
    codes = daily['weathercode']        || []

    # dates[1..] skips today; each_with_index gives the offset into the
    # other parallel arrays (offset by 1 to align with the sliced dates).
    dates[1..].each_with_index.map do |date_str, idx|
      actual_idx = idx + 1

      DailyForecast.new(
        date:      Date.parse(date_str),
        high_temp: highs[actual_idx],
        low_temp:  lows[actual_idx],
        condition: WmoWeatherCodeMapper.description(codes[actual_idx])
      )
    end
  end

  # Writes the Forecast to the cache keyed by zip code.
  # A blank zip code is skipped (partial geocoding result).
  #
  # @param zip_code [String, nil]
  # @param forecast [Forecast]
  def write_to_cache(zip_code, forecast)
    return if zip_code.blank?

    Rails.cache.write(cache_key(zip_code), forecast, expires_in: CACHE_TTL)
  end

  # Writes a separate, longer-lived "last known good" forecast snapshot.
  #
  # @param zip_code [String, nil]
  # @param forecast [Forecast]
  def write_last_known(zip_code, forecast)
    return if zip_code.blank?

    Rails.cache.write(last_known_key(zip_code), forecast, expires_in: LAST_KNOWN_FORECAST_TTL)
  end

  # Reads the last known good forecast snapshot.
  #
  # @param zip_code [String, nil]
  # @return [Forecast, nil]
  def read_last_known(zip_code)
    return nil if zip_code.blank?

    Rails.cache.read(last_known_key(zip_code))
  end

  # Builds a namespaced, human-readable cache key.
  #
  # @param zip_code [String]
  # @return [String] e.g. "forecast/zip/10001"
  def cache_key(zip_code)
    "#{CACHE_KEY_PREFIX}/#{zip_code}"
  end

  # @param zip_code [String]
  # @return [String]
  def last_known_key(zip_code)
    "#{LAST_KNOWN_KEY_PREFIX}/#{zip_code}"
  end

  # Minimal structured log helper for easier production diagnostics.
  #
  # @param event [String]
  # @param payload [Hash]
  def log_info(event, payload = {})
    Rails.logger.info({ event: event, address: @address }.merge(payload).to_json)
  end
end

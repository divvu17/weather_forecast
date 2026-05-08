# frozen_string_literal: true

# =============================================================================
# Forecast
#
# Value object that aggregates all weather data for a given location.
# Returned by ForecastService and passed directly to the view layer.
#
# Decomposition:
#   - location           : Location value object (geocoded address data)
#   - current_temp       : current temperature in °F (Integer)
#   - feels_like         : apparent/feels-like temperature in °F (Integer)
#   - high_temp          : today's forecasted high in °F (Integer)
#   - low_temp           : today's forecasted low in °F (Integer)
#   - condition          : current weather condition description (String)
#   - extended_forecast  : Array<DailyForecast> for the next 6 days
#   - cached             : Boolean – true when result was served from cache
#   - retrieved_at       : Time the object was created (not when it was cached)
#
# Design notes:
#   - #cached is writable so ForecastService can flag a reconstructed
#     object without duplicating all build logic.
#   - Temperatures are stored as Integers for clean display.
#   - The object must remain marshal-serializable (no lambdas, IO objects,
#     etc.) so Rails.cache can persist it with the file store.
# =============================================================================
class Forecast
  attr_reader :location, :current_temp, :feels_like, :high_temp, :low_temp,
              :condition, :extended_forecast, :retrieved_at

  # Allows ForecastService to mark a reconstituted cache hit as cached.
  attr_writer :cached, :stale

  # @param location          [Location]
  # @param current_temp      [Numeric]
  # @param feels_like        [Numeric]
  # @param high_temp         [Numeric]
  # @param low_temp          [Numeric]
  # @param condition         [String]
  # @param extended_forecast [Array<DailyForecast>]
  # @param cached            [Boolean]
  # @param stale             [Boolean]
  def initialize(location:, current_temp:, feels_like:, high_temp:, low_temp:,
                 condition:, extended_forecast: [], cached: false, stale: false)
    @location          = location
    @current_temp      = current_temp.to_f.round
    @feels_like        = feels_like.to_f.round
    @high_temp         = high_temp.to_f.round
    @low_temp          = low_temp.to_f.round
    @condition         = condition.to_s
    @extended_forecast = Array(extended_forecast)
    @cached            = cached
    @stale             = stale
    @retrieved_at      = Time.current
  end

  # @return [Boolean] true when this forecast was served from the cache
  def cached?
    @cached == true
  end

  # @return [Boolean] true when this forecast is stale fallback data
  def stale?
    @stale == true
  end
end

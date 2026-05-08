# frozen_string_literal: true

# =============================================================================
# WeatherApiClient
#
# Low-level HTTP wrapper for the Open-Meteo weather API.
#
# API used:   https://api.open-meteo.com/v1/forecast
# Auth:       None required – Open-Meteo is a free, open-source weather API.
# Docs:       https://open-meteo.com/en/docs
#
# Design notes:
#   - Intentionally kept thin; it makes the HTTP call and returns raw parsed
#     JSON.  All domain mapping lives in ForecastService.
#   - Raises WeatherApiError on any non-success response, allowing the
#     orchestrating service to translate it into a user-friendly message.
#   - REQUEST_TIMEOUT prevents the app from hanging if the API is slow.
#
# Decomposition:
#   WeatherApiClient
#     .fetch_forecast(latitude:, longitude:) – public factory / entry point
#     #fetch_forecast                        – instance entry point
#     #query_params                          – builds Open-Meteo query params
# =============================================================================
class WeatherApiClient
  include HTTParty

  BASE_URL        = 'https://api.open-meteo.com'
  FORECAST_PATH   = '/v1/forecast'
  REQUEST_TIMEOUT = 10 # seconds
  MAX_RETRIES     = 1

  # ---------------------------------------------------------------------------
  # Custom Exceptions
  # ---------------------------------------------------------------------------

  # Raised when the Open-Meteo API returns a non-success HTTP status
  class WeatherApiError < StandardError; end

  # ---------------------------------------------------------------------------
  # Public Interface
  # ---------------------------------------------------------------------------

  # Convenience factory method.
  #
  # @param latitude  [Float] geographic latitude
  # @param longitude [Float] geographic longitude
  # @return [Hash] parsed JSON response
  # @raise [WeatherApiError] on API failure
  def self.fetch_forecast(latitude:, longitude:)
    new(latitude: latitude, longitude: longitude).fetch_forecast
  end

  # @param latitude  [Float]
  # @param longitude [Float]
  def initialize(latitude:, longitude:)
    @latitude  = latitude
    @longitude = longitude
  end

  # Makes the HTTP GET request to Open-Meteo and returns the parsed response.
  #
  # Fields requested:
  #   current – temperature_2m, apparent_temperature, weathercode
  #   daily   – temperature_2m_max, temperature_2m_min, weathercode
  #
  # All temperatures are requested in Fahrenheit.
  #
  # @return [Hash]
  # @raise [WeatherApiError]
  def fetch_forecast
    retries = 0

    begin
      response = self.class.get(
        "#{BASE_URL}#{FORECAST_PATH}",
        query: query_params,
        timeout: REQUEST_TIMEOUT
      )

      raise WeatherApiError, "Weather API returned HTTP #{response.code}" unless response.success?

      response.parsed_response
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, SocketError => e
      retries += 1
      retry if retries <= MAX_RETRIES

      raise WeatherApiError, "Weather API request timed out: #{e.class}"
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  private

  # Builds the query string for Open-Meteo.
  #
  # forecast_days: 7  → today + 6 upcoming days (used for extended forecast)
  # timezone: auto    → let Open-Meteo infer timezone from coordinates
  #
  # @return [Hash]
  def query_params
    {
      latitude:         @latitude,
      longitude:        @longitude,
      current:          'temperature_2m,apparent_temperature,weathercode',
      daily:            'temperature_2m_max,temperature_2m_min,weathercode',
      temperature_unit: 'fahrenheit',
      timezone:         'auto',
      forecast_days:    7
    }
  end
end

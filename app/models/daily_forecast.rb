# frozen_string_literal: true

# =============================================================================
# DailyForecast
#
# Value object representing a single day in the extended (multi-day) forecast.
# Used as elements of Forecast#extended_forecast.
#
# Decomposition:
#   - date      : Ruby Date object for the forecast day
#   - high_temp : daytime high temperature in °F (Integer)
#   - low_temp  : overnight low temperature in °F (Integer)
#   - condition : human-readable weather description (e.g. "Partly Cloudy")
#
# Design notes:
#   - Temperatures are stored as Integers (rounded) for display simplicity.
#   - Immutable after initialization; no public setters.
# =============================================================================
class DailyForecast
  attr_reader :date, :high_temp, :low_temp, :condition

  # @param date      [Date]
  # @param high_temp [Numeric]
  # @param low_temp  [Numeric]
  # @param condition [String]
  def initialize(date:, high_temp:, low_temp:, condition:)
    @date      = date
    @high_temp = high_temp.to_f.round
    @low_temp  = low_temp.to_f.round
    @condition = condition.to_s
  end
end

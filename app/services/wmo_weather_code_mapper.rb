# frozen_string_literal: true

# =============================================================================
# WmoWeatherCodeMapper
#
# Maps WMO Weather Interpretation Codes (used by Open-Meteo) to human-readable
# condition descriptions.
#
# Reference: https://open-meteo.com/en/docs#weathervariables
#
# Design notes:
#   - Stateless utility module; all behaviour is exposed as class-level methods.
#   - CODES is frozen to prevent accidental runtime mutation.
#   - Falls back gracefully to 'Unknown' for unmapped codes.
# =============================================================================
class WmoWeatherCodeMapper
  CODES = {
    0  => 'Clear Sky',
    1  => 'Mainly Clear',
    2  => 'Partly Cloudy',
    3  => 'Overcast',
    45 => 'Foggy',
    48 => 'Icy Fog',
    51 => 'Light Drizzle',
    53 => 'Moderate Drizzle',
    55 => 'Dense Drizzle',
    56 => 'Light Freezing Drizzle',
    57 => 'Heavy Freezing Drizzle',
    61 => 'Slight Rain',
    63 => 'Moderate Rain',
    65 => 'Heavy Rain',
    66 => 'Light Freezing Rain',
    67 => 'Heavy Freezing Rain',
    71 => 'Slight Snowfall',
    73 => 'Moderate Snowfall',
    75 => 'Heavy Snowfall',
    77 => 'Snow Grains',
    80 => 'Slight Rain Showers',
    81 => 'Moderate Rain Showers',
    82 => 'Violent Rain Showers',
    85 => 'Slight Snow Showers',
    86 => 'Heavy Snow Showers',
    95 => 'Thunderstorm',
    96 => 'Thunderstorm with Slight Hail',
    99 => 'Thunderstorm with Heavy Hail'
  }.freeze

  # Returns a human-readable description for the given WMO code.
  #
  # @param code [Integer, String] WMO weather interpretation code
  # @return [String] condition description, or 'Unknown' if unmapped
  def self.description(code)
    CODES[code.to_i] || 'Unknown'
  end
end

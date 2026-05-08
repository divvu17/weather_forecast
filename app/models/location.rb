# frozen_string_literal: true

# =============================================================================
# Location
#
# Value object that represents a geocoded address.  Instances are immutable
# after initialization (no setters exposed).
#
# Decomposition:
#   - address       : raw string entered by the user
#   - zip_code      : 5-digit US postal code (used as the cache key)
#   - city / state  : human-readable city and state names
#   - latitude      : geographic latitude (Float)
#   - longitude     : geographic longitude (Float)
#   - display_name  : full formatted address returned by the geocoding API
#
# Design notes:
#   - Coordinates are coerced to Float on initialization so callers receive
#     a consistent type regardless of whether the source data was a String.
#   - #valid? guards against partially geocoded results before any API call
#     is made for weather data.
# =============================================================================
class Location
  attr_reader :address, :zip_code, :city, :state, :latitude, :longitude, :display_name

  # @param address      [String]
  # @param zip_code     [String, nil]
  # @param city         [String, nil]
  # @param state        [String, nil]
  # @param latitude     [String, Float]
  # @param longitude    [String, Float]
  # @param display_name [String]
  def initialize(address:, zip_code:, city:, state:, latitude:, longitude:, display_name:)
    @address      = address.to_s.strip
    @zip_code     = zip_code.to_s.strip.presence
    @city         = city.to_s.strip.presence
    @state        = state.to_s.strip.presence
    @latitude     = latitude.to_f
    @longitude    = longitude.to_f
    @display_name = display_name.to_s.strip
  end

  # Returns true when the location contains the minimum data required to
  # fetch a weather forecast: a zip code and non-zero coordinates.
  #
  # @return [Boolean]
  def valid?
    zip_code.present? && latitude != 0.0 && longitude != 0.0
  end

  # Convenience accessor for passing coordinates to the weather client.
  #
  # @return [Array<Float>] [latitude, longitude]
  def coordinates
    [latitude, longitude]
  end

  # Human-readable summary used in views and log output.
  #
  # @return [String]
  def to_s
    display_name.presence || "#{city}, #{state} #{zip_code}"
  end
end

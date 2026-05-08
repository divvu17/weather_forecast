# frozen_string_literal: true

# =============================================================================
# GeocodingService
#
# Converts a raw address string into a Location value object by querying the
# Nominatim (OpenStreetMap) geocoding API.
#
# API used:   https://nominatim.openstreetmap.org/search
# Auth:       None required
# Rate limit: 1 request per second (Nominatim usage policy)
#
# Design notes:
#   - Follows the Command pattern: instantiate with an address, call #call.
#   - The class-level .call factory method is provided for convenience so
#     callers can write GeocodingService.call(address) without managing state.
#   - Custom exceptions (GeocodingError, AddressNotFoundError) let callers
#     handle geocoding failures distinctly from other StandardErrors.
#   - Private helper methods keep #call readable and single-purpose.
#
# Decomposition:
#   GeocodingService
#     .call(address)         – public factory / entry point
#     #call                  – instance entry point
#     #fetch_geocoding_data  – makes the HTTP request; raises on failure
#     #parse_location        – maps raw API hash → Location value object
#     #query_params          – builds Nominatim query parameters
#     #request_headers       – adds required User-Agent header
# =============================================================================
class GeocodingService
  include HTTParty

  NOMINATIM_BASE_URL = 'https://nominatim.openstreetmap.org'
  GEOCODE_PATH       = '/search'
  REQUEST_TIMEOUT    = 10 # seconds

  # ---------------------------------------------------------------------------
  # Custom Exceptions
  # ---------------------------------------------------------------------------

  # Raised for any geocoding API failure (network error, unexpected response)
  class GeocodingError < StandardError; end

  # Raised specifically when the address cannot be found in the geocoding API
  class AddressNotFoundError < GeocodingError; end

  # ---------------------------------------------------------------------------
  # Public Interface
  # ---------------------------------------------------------------------------

  # Convenience factory so callers don't need to manage an instance.
  #
  # @param address [String] raw address string from the user
  # @return [Location]
  # @raise [AddressNotFoundError] when the address yields no results
  # @raise [GeocodingError] when the API returns a non-success response
  def self.call(address)
    new(address).call
  end

  # @param address [String]
  def initialize(address)
    @address = address.to_s.strip
  end

  # Geocodes the stored address and returns a Location value object.
  #
  # @return [Location]
  def call
    raw_result = fetch_geocoding_data
    parse_location(raw_result)
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  private

  # Calls the Nominatim API and returns the first result hash.
  #
  # If a full-address lookup fails and a US ZIP is present in the input,
  # retries using the ZIP code to avoid false negatives on minor street-name
  # formatting differences.
  #
  # @return [Hash] first result from Nominatim
  # @raise [GeocodingError, AddressNotFoundError]
  def fetch_geocoding_data
    results = request_results(query_params(@address))
    return results.first if results.present?

    zip = extract_us_zip(@address)
    if zip.present?
      zip_results = request_results(query_params(zip))
      return zip_results.first if zip_results.present?
    end

    raise AddressNotFoundError, "No geocoding results found for: \"#{@address}\""
  end

  # Performs one Nominatim request and returns parsed results.
  #
  # @param params [Hash]
  # @return [Array<Hash>]
  # @raise [GeocodingError]
  def request_results(params)
    response = self.class.get(
      "#{NOMINATIM_BASE_URL}#{GEOCODE_PATH}",
      query: params,
      timeout: REQUEST_TIMEOUT,
      headers: request_headers
    )

    unless response.success?
      raise GeocodingError, "Geocoding API returned HTTP #{response.code}"
    end

    response.parsed_response
  end

  # Maps a raw Nominatim result hash to a Location value object.
  #
  # Nominatim nests address components under the 'address' key.
  # City-level names vary: some responses use 'city', others 'town' or 'village'.
  #
  # @param data [Hash]
  # @return [Location]
  def parse_location(data)
    address_details = data['address'] || {}

    Location.new(
      address:      @address,
      zip_code:     address_details['postcode'],
      city:         address_details['city'] ||
                    address_details['town']  ||
                    address_details['village'],
      state:        address_details['state'],
      latitude:     data['lat'],
      longitude:    data['lon'],
      display_name: data['display_name']
    )
  end

  # Query parameters sent to Nominatim.
  #
  # @return [Hash]
  # @param query [String]
  # @return [Hash]
  def query_params(query)
    {
      q:              query,
      format:         'json',
      addressdetails: 1,
      countrycodes:   'us',
      limit:          1
    }
  end

  # Extracts a US ZIP code from a free-form address string.
  # Supports both 5-digit and ZIP+4 formats; returns only the 5-digit ZIP.
  #
  # @param text [String]
  # @return [String, nil]
  def extract_us_zip(text)
    match = text.to_s.match(/\b(\d{5})(?:-\d{4})?\b/)
    match && match[1]
  end

  # Nominatim's usage policy requires a descriptive User-Agent header.
  # See: https://operations.osmfoundation.org/policies/nominatim/
  #
  # @return [Hash]
  def request_headers
    {
      'User-Agent' => 'WeatherForecastApp/1.0 (rails-coding-assignment)',
      'Accept'     => 'application/json'
    }
  end
end

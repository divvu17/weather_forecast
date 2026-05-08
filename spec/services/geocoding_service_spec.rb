# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeocodingService do
  # Nominatim response fixture for a successful geocode of the White House
  let(:nominatim_success_body) do
    [
      {
        'lat'          => '38.8976',
        'lon'          => '-77.0366',
        'display_name' => '1600 Pennsylvania Ave NW, Washington, DC 20500, USA',
        'address'      => {
          'house_number' => '1600',
          'road'         => 'Pennsylvania Avenue Northwest',
          'city'         => 'Washington',
          'state'        => 'District of Columbia',
          'postcode'     => '20500',
          'country'      => 'United States'
        }
      }
    ].to_json
  end

  let(:nominatim_url) do
    'https://nominatim.openstreetmap.org/search'
  end

  before do
    # Stub all Nominatim calls by default; individual examples override as needed
    stub_request(:get, nominatim_url)
      .with(query: hash_including({}))
      .to_return(
        status:  200,
        body:    nominatim_success_body,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # ── Successful geocoding ───────────────────────────────────────────────────

  describe '.call' do
    subject(:location) { described_class.call('1600 Pennsylvania Ave, Washington, DC') }

    it 'returns a Location value object' do
      expect(location).to be_a Location
    end

    it 'sets the latitude' do
      expect(location.latitude).to eq 38.8976
    end

    it 'sets the longitude' do
      expect(location.longitude).to eq(-77.0366)
    end

    it 'sets the zip_code from the address details' do
      expect(location.zip_code).to eq '20500'
    end

    it 'sets the city' do
      expect(location.city).to eq 'Washington'
    end

    it 'sets the state' do
      expect(location.state).to eq 'District of Columbia'
    end

    it 'sets the display_name' do
      expect(location.display_name).to include 'Pennsylvania'
    end

    it 'passes the original address through' do
      expect(location.address).to eq '1600 Pennsylvania Ave, Washington, DC'
    end
  end

  # ── Address not found ──────────────────────────────────────────────────────

  describe '.call with empty results' do
    before do
      stub_request(:get, nominatim_url)
        .with(query: hash_including({}))
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })
    end

    it 'raises AddressNotFoundError' do
      expect { described_class.call('zzz not a real address xyz') }
        .to raise_error(GeocodingService::AddressNotFoundError, /No geocoding results found/)
    end
  end

  # ── ZIP fallback lookup ───────────────────────────────────────────────────

  describe '.call when full address misses but ZIP exists' do
    let(:zip_only_body) do
      [
        {
          'lat'          => '39.5186',
          'lon'          => '-104.7614',
          'display_name' => 'Parker, CO 80134, USA',
          'address'      => {
            'city'     => 'Parker',
            'state'    => 'Colorado',
            'postcode' => '80134'
          }
        }
      ].to_json
    end

    before do
      stub_request(:get, nominatim_url)
        .with(query: hash_including('q' => '8994 RedBud Street, Parker, CO, 80134'))
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, nominatim_url)
        .with(query: hash_including('q' => '80134'))
        .to_return(status: 200, body: zip_only_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns a location from the ZIP fallback request' do
      location = described_class.call('8994 RedBud Street, Parker, CO, 80134')

      expect(location.zip_code).to eq '80134'
      expect(location.city).to eq 'Parker'
      expect(location.state).to eq 'Colorado'
    end
  end

  describe '.call when full address and ZIP fallback both miss' do
    before do
      stub_request(:get, nominatim_url)
        .with(query: hash_including('q' => '8994 RedBud Street, Parker, CO, 80134'))
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })

      stub_request(:get, nominatim_url)
        .with(query: hash_including('q' => '80134'))
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })
    end

    it 'raises AddressNotFoundError' do
      expect { described_class.call('8994 RedBud Street, Parker, CO, 80134') }
        .to raise_error(GeocodingService::AddressNotFoundError, /No geocoding results found/)
    end
  end

  # ── API error ─────────────────────────────────────────────────────────────

  describe '.call with API error' do
    before do
      stub_request(:get, nominatim_url)
        .with(query: hash_including({}))
        .to_return(status: 503, body: 'Service Unavailable')
    end

    it 'raises GeocodingError' do
      expect { described_class.call('1600 Pennsylvania Ave') }
        .to raise_error(GeocodingService::GeocodingError, /HTTP 503/)
    end
  end

  # ── Network timeout ───────────────────────────────────────────────────────

  describe '.call with network timeout' do
    before do
      stub_request(:get, nominatim_url)
        .with(query: hash_including({}))
        .to_timeout
    end

    it 'raises an exception' do
      expect { described_class.call('1600 Pennsylvania Ave') }.to raise_error(StandardError)
    end
  end

  # ── City fallback (town/village) ──────────────────────────────────────────

  describe '.call when address uses "town" instead of "city"' do
    let(:town_body) do
      [
        {
          'lat'          => '42.1234',
          'lon'          => '-71.5678',
          'display_name' => '10 Main St, Smalltown, MA 01234, USA',
          'address'      => {
            'town'     => 'Smalltown',
            'state'    => 'Massachusetts',
            'postcode' => '01234'
          }
        }
      ].to_json
    end

    before do
      stub_request(:get, nominatim_url)
        .with(query: hash_including({}))
        .to_return(status: 200, body: town_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'falls back to the town field for city' do
      location = described_class.call('10 Main St, Smalltown, MA')
      expect(location.city).to eq 'Smalltown'
    end
  end
end

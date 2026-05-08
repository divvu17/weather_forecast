# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForecastService do
  let(:address)  { '1600 Pennsylvania Ave, Washington, DC' }
  let(:location) { build(:location) }

  # Raw Open-Meteo API response hash (matches what WeatherApiClient returns)
  let(:raw_weather_data) do
    {
      'current' => {
        'temperature_2m'       => 68.5,
        'apparent_temperature' => 65.1,
        'weathercode'          => 2
      },
      'daily' => {
        'time'               => %w[2026-05-06 2026-05-07 2026-05-08 2026-05-09 2026-05-10 2026-05-11 2026-05-12],
        'temperature_2m_max' => [74.0, 76.5, 70.1, 68.0, 72.3, 75.0, 73.0],
        'temperature_2m_min' => [55.0, 57.2, 53.0, 50.0, 54.1, 56.0, 52.0],
        'weathercode'        => [2, 3, 61, 0, 1, 2, 45]
      }
    }
  end

  before do
    allow(GeocodingService).to receive(:call).with(address).and_return(location)
    allow(WeatherApiClient).to receive(:fetch_forecast)
      .with(latitude: location.latitude, longitude: location.longitude)
      .and_return(raw_weather_data)
  end

  # ── Cache miss (first request) ─────────────────────────────────────────────

  describe '.call on a cache miss' do
    it 'returns a Forecast' do
      expect(described_class.call(address)).to be_a Forecast
    end

    it 'marks the forecast as not cached' do
      expect(described_class.call(address).cached?).to be false
    end

    it 'sets the current temperature' do
      expect(described_class.call(address).current_temp).to eq 69 # 68.5 rounded
    end

    it 'sets the feels_like temperature' do
      expect(described_class.call(address).feels_like).to eq 65 # 65.1 rounded
    end

    it 'sets the high temperature from today (index 0)' do
      expect(described_class.call(address).high_temp).to eq 74 # 74.0 rounded
    end

    it 'sets the low temperature from today (index 0)' do
      expect(described_class.call(address).low_temp).to eq 55 # 55.0 rounded
    end

    it 'maps the weather code to a condition description' do
      expect(described_class.call(address).condition).to eq 'Partly Cloudy'
    end

    it 'builds 6 extended forecast days (skipping today)' do
      expect(described_class.call(address).extended_forecast.length).to eq 6
    end

    it 'writes the forecast to the cache' do
      described_class.call(address)
      cached = Rails.cache.read("forecast/zip/#{location.zip_code}")
      expect(cached).to be_a Forecast
    end

    it 'writes a last-known forecast snapshot' do
      described_class.call(address)
      snapshot = Rails.cache.read("forecast/last_known/zip/#{location.zip_code}")
      expect(snapshot).to be_a Forecast
    end

    it 'calls the weather API exactly once' do
      described_class.call(address)
      expect(WeatherApiClient).to have_received(:fetch_forecast).once
    end
  end

  # ── Cache hit (second request for same zip) ────────────────────────────────

  describe '.call on a cache hit' do
    before do
      # Seed the cache with a pre-built forecast
      existing = build(:forecast, location: location, cached: false)
      Rails.cache.write("forecast/zip/#{location.zip_code}", existing, expires_in: 30.minutes)
    end

    it 'returns a Forecast marked as cached' do
      expect(described_class.call(address).cached?).to be true
    end

    it 'does NOT call the weather API' do
      described_class.call(address)
      expect(WeatherApiClient).not_to have_received(:fetch_forecast)
    end
  end

  # ── Geocoding failure ──────────────────────────────────────────────────────

  describe '.call when geocoding fails' do
    before do
      allow(GeocodingService).to receive(:call)
        .and_raise(GeocodingService::AddressNotFoundError, 'No results found')
    end

    it 'raises ForecastError' do
      expect { described_class.call(address) }
        .to raise_error(ForecastService::ForecastError, /No results found/)
    end
  end

  describe '.call when geocoding API is unavailable' do
    before do
      allow(GeocodingService).to receive(:call)
        .and_raise(GeocodingService::GeocodingError, 'HTTP 503')
    end

    it 'raises ForecastError wrapping the geocoding error' do
      expect { described_class.call(address) }
        .to raise_error(ForecastService::ForecastError, /Unable to geocode/)
    end
  end

  # ── Weather API failure ────────────────────────────────────────────────────

  describe '.call when the weather API is unavailable' do
    before do
      allow(WeatherApiClient).to receive(:fetch_forecast)
        .and_raise(WeatherApiClient::WeatherApiError, 'HTTP 500')
    end

    it 'raises ForecastError wrapping the weather error' do
      expect { described_class.call(address) }
        .to raise_error(ForecastService::ForecastError, /Unable to retrieve weather data/)
    end
  end

  describe '.call when weather API fails but last-known exists' do
    let(:last_known) { build(:forecast, location: location, cached: false, stale: false) }

    before do
      Rails.cache.write("forecast/last_known/zip/#{location.zip_code}", last_known, expires_in: 24.hours)
      allow(WeatherApiClient).to receive(:fetch_forecast)
        .and_raise(WeatherApiClient::WeatherApiError, 'HTTP 503')
    end

    it 'returns a forecast instead of raising' do
      expect(described_class.call(address)).to be_a Forecast
    end

    it 'marks the response as stale' do
      expect(described_class.call(address).stale?).to be true
    end

    it 'marks the response as cached' do
      expect(described_class.call(address).cached?).to be true
    end
  end

  # ── Extended forecast structure ────────────────────────────────────────────

  describe 'extended_forecast structure' do
    subject(:days) { described_class.call(address).extended_forecast }

    it 'contains DailyForecast objects' do
      expect(days).to all(be_a(DailyForecast))
    end

    it 'starts from tomorrow (skips today)' do
      expect(days.first.date).to eq Date.parse('2026-05-07')
    end

    it 'sets the correct high for the first extended day' do
      expect(days.first.high_temp).to eq 77 # 76.5 rounded
    end

    it 'sets the correct low for the first extended day' do
      expect(days.first.low_temp).to eq 57 # 57.2 rounded
    end

    it 'maps the weather code for each day' do
      expect(days.first.condition).to eq 'Overcast'
    end
  end

  # ── Cache key isolation (different zip codes don't share cache) ────────────

  describe 'cache isolation by zip code' do
    let(:location_a) { build(:location, zip_code: '10001', latitude: 40.7484, longitude: -73.9967) }
    let(:location_b) { build(:location, zip_code: '90210', latitude: 34.0901, longitude: -118.4065) }

    before do
      allow(GeocodingService).to receive(:call).with('Address A').and_return(location_a)
      allow(GeocodingService).to receive(:call).with('Address B').and_return(location_b)
      allow(WeatherApiClient).to receive(:fetch_forecast).and_return(raw_weather_data)
    end

    it 'caches each zip code independently' do
      described_class.call('Address A')
      described_class.call('Address B')

      expect(Rails.cache.read('forecast/zip/10001')).to be_a Forecast
      expect(Rails.cache.read('forecast/zip/90210')).to be_a Forecast
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeatherApiClient do
  let(:latitude)  { 38.8976 }
  let(:longitude) { -77.0366 }
  let(:api_url)   { 'https://api.open-meteo.com/v1/forecast' }

  # Minimal Open-Meteo response fixture
  let(:success_body) do
    {
      'current' => {
        'temperature_2m'       => 68.5,
        'apparent_temperature' => 65.1,
        'weathercode'          => 2
      },
      'daily' => {
        'time'                => %w[2026-05-06 2026-05-07 2026-05-08 2026-05-09 2026-05-10 2026-05-11 2026-05-12],
        'temperature_2m_max'  => [74.0, 76.5, 70.1, 68.0, 72.3, 75.0, 73.0],
        'temperature_2m_min'  => [55.0, 57.2, 53.0, 50.0, 54.1, 56.0, 52.0],
        'weathercode'         => [2, 3, 61, 0, 1, 2, 45]
      }
    }.to_json
  end

  before do
    stub_request(:get, api_url)
      .with(query: hash_including('latitude' => latitude.to_s))
      .to_return(
        status:  200,
        body:    success_body,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # ── Successful fetch ───────────────────────────────────────────────────────

  describe '.fetch_forecast' do
    subject(:result) { described_class.fetch_forecast(latitude: latitude, longitude: longitude) }

    it 'returns a Hash' do
      expect(result).to be_a Hash
    end

    it 'includes a "current" key' do
      expect(result).to have_key 'current'
    end

    it 'includes a "daily" key' do
      expect(result).to have_key 'daily'
    end

    it 'returns the current temperature' do
      expect(result.dig('current', 'temperature_2m')).to eq 68.5
    end
  end

  # ── API error ─────────────────────────────────────────────────────────────

  describe '.fetch_forecast with API error' do
    before do
      stub_request(:get, api_url)
        .with(query: hash_including({}))
        .to_return(status: 500, body: 'Internal Server Error')
    end

    it 'raises WeatherApiError' do
      expect { described_class.fetch_forecast(latitude: latitude, longitude: longitude) }
        .to raise_error(WeatherApiClient::WeatherApiError, /HTTP 500/)
    end
  end

  # ── Network timeout ───────────────────────────────────────────────────────

  describe '.fetch_forecast with network timeout' do
    before do
      stub_request(:get, api_url).with(query: hash_including({})).to_timeout
    end

    it 'raises WeatherApiError after retry is exhausted' do
      expect { described_class.fetch_forecast(latitude: latitude, longitude: longitude) }
        .to raise_error(WeatherApiClient::WeatherApiError, /timed out/)
    end
  end

  describe '.fetch_forecast retries once for timeout and succeeds' do
    before do
      stub_request(:get, api_url)
        .with(query: hash_including({}))
        .to_timeout.then
        .to_return(status: 200, body: success_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns parsed forecast data after retry' do
      result = described_class.fetch_forecast(latitude: latitude, longitude: longitude)
      expect(result.dig('current', 'temperature_2m')).to eq 68.5
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Forecast do
  let(:location) { build(:location) }

  subject(:forecast) do
    described_class.new(
      location:          location,
      current_temp:      72.6,
      feels_like:        69.1,
      high_temp:         78.9,
      low_temp:          55.2,
      condition:         'Partly Cloudy',
      extended_forecast: [],
      cached:            false
    )
  end

  # ── Attribute readers ──────────────────────────────────────────────────────

  describe 'attribute readers' do
    it 'rounds current_temp to the nearest integer' do
      expect(forecast.current_temp).to eq 73
    end

    it 'rounds feels_like to the nearest integer' do
      expect(forecast.feels_like).to eq 69
    end

    it 'rounds high_temp to the nearest integer' do
      expect(forecast.high_temp).to eq 79
    end

    it 'rounds low_temp to the nearest integer' do
      expect(forecast.low_temp).to eq 55
    end

    it 'stores the condition string' do
      expect(forecast.condition).to eq 'Partly Cloudy'
    end

    it 'stores the location' do
      expect(forecast.location).to eq location
    end

    it 'defaults extended_forecast to an empty array' do
      expect(forecast.extended_forecast).to eq []
    end

    it 'records retrieved_at as a Time' do
      expect(forecast.retrieved_at).to be_a Time
    end
  end

  # ── #cached? ──────────────────────────────────────────────────────────────

  describe '#cached?' do
    context 'when cached: false' do
      it 'returns false' do
        expect(forecast.cached?).to be false
      end
    end

    context 'when cached: true' do
      subject(:cached_forecast) do
        described_class.new(
          location: location, current_temp: 70, feels_like: 68,
          high_temp: 75, low_temp: 55, condition: 'Clear Sky', cached: true
        )
      end

      it 'returns true' do
        expect(cached_forecast.cached?).to be true
      end
    end

    context 'when cached is set via the writer' do
      it 'reflects the updated value' do
        forecast.cached = true
        expect(forecast.cached?).to be true
      end
    end
  end

  describe '#stale?' do
    it 'defaults to false' do
      expect(forecast.stale?).to be false
    end

    it 'returns true when initialized with stale: true' do
      stale_forecast = described_class.new(
        location: location, current_temp: 70, feels_like: 68,
        high_temp: 75, low_temp: 55, condition: 'Clear Sky', stale: true
      )
      expect(stale_forecast.stale?).to be true
    end

    it 'reflects value set via writer' do
      forecast.stale = true
      expect(forecast.stale?).to be true
    end
  end

  # ── extended_forecast ─────────────────────────────────────────────────────

  describe 'extended_forecast' do
    it 'wraps a single DailyForecast in an array' do
      day = build(:daily_forecast)
      f   = described_class.new(
        location: location, current_temp: 70, feels_like: 68,
        high_temp: 75, low_temp: 55, condition: 'Clear Sky',
        extended_forecast: day
      )
      expect(f.extended_forecast).to eq [day]
    end

    it 'accepts an array of DailyForecast objects' do
      days = build_list(:daily_forecast, 3)
      f    = described_class.new(
        location: location, current_temp: 70, feels_like: 68,
        high_temp: 75, low_temp: 55, condition: 'Clear Sky',
        extended_forecast: days
      )
      expect(f.extended_forecast.length).to eq 3
    end
  end
end

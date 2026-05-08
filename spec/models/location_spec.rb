# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Location do
  subject(:location) do
    described_class.new(
      address:      '123 Main St, Springfield, IL 62701',
      zip_code:     '62701',
      city:         'Springfield',
      state:        'Illinois',
      latitude:     '39.7817',
      longitude:    '-89.6501',
      display_name: '123 Main St, Springfield, IL 62701, USA'
    )
  end

  # ── Attribute readers ──────────────────────────────────────────────────────

  describe 'attribute readers' do
    it 'exposes the raw address string' do
      expect(location.address).to eq '123 Main St, Springfield, IL 62701'
    end

    it 'exposes the zip code' do
      expect(location.zip_code).to eq '62701'
    end

    it 'exposes the city' do
      expect(location.city).to eq 'Springfield'
    end

    it 'exposes the state' do
      expect(location.state).to eq 'Illinois'
    end

    it 'coerces latitude to Float' do
      expect(location.latitude).to eq 39.7817
      expect(location.latitude).to be_a Float
    end

    it 'coerces longitude to Float' do
      expect(location.longitude).to eq(-89.6501)
      expect(location.longitude).to be_a Float
    end

    it 'exposes the display_name' do
      expect(location.display_name).to eq '123 Main St, Springfield, IL 62701, USA'
    end
  end

  # ── #valid? ────────────────────────────────────────────────────────────────

  describe '#valid?' do
    it 'returns true when zip code and non-zero coordinates are present' do
      expect(location).to be_valid
    end

    it 'returns false when zip_code is nil' do
      loc = described_class.new(
        address: 'somewhere', zip_code: nil,
        city: 'X', state: 'Y', latitude: 1.0, longitude: 1.0,
        display_name: 'X'
      )
      expect(loc).not_to be_valid
    end

    it 'returns false when zip_code is blank' do
      loc = described_class.new(
        address: 'somewhere', zip_code: '',
        city: 'X', state: 'Y', latitude: 1.0, longitude: 1.0,
        display_name: 'X'
      )
      expect(loc).not_to be_valid
    end

    it 'returns false when latitude is zero' do
      loc = described_class.new(
        address: 'somewhere', zip_code: '12345',
        city: 'X', state: 'Y', latitude: 0, longitude: 1.0,
        display_name: 'X'
      )
      expect(loc).not_to be_valid
    end

    it 'returns false when longitude is zero' do
      loc = described_class.new(
        address: 'somewhere', zip_code: '12345',
        city: 'X', state: 'Y', latitude: 1.0, longitude: 0,
        display_name: 'X'
      )
      expect(loc).not_to be_valid
    end
  end

  # ── #coordinates ──────────────────────────────────────────────────────────

  describe '#coordinates' do
    it 'returns [latitude, longitude]' do
      expect(location.coordinates).to eq [39.7817, -89.6501]
    end
  end

  # ── #to_s ─────────────────────────────────────────────────────────────────

  describe '#to_s' do
    it 'returns the display_name when present' do
      expect(location.to_s).to eq '123 Main St, Springfield, IL 62701, USA'
    end

    it 'falls back to city/state/zip when display_name is blank' do
      loc = described_class.new(
        address: 'somewhere', zip_code: '62701',
        city: 'Springfield', state: 'Illinois',
        latitude: 1.0, longitude: 1.0, display_name: ''
      )
      expect(loc.to_s).to eq 'Springfield, Illinois 62701'
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WmoWeatherCodeMapper do
  describe '.description' do
    {
      0  => 'Clear Sky',
      1  => 'Mainly Clear',
      2  => 'Partly Cloudy',
      3  => 'Overcast',
      45 => 'Foggy',
      61 => 'Slight Rain',
      63 => 'Moderate Rain',
      65 => 'Heavy Rain',
      71 => 'Slight Snowfall',
      80 => 'Slight Rain Showers',
      95 => 'Thunderstorm',
      99 => 'Thunderstorm with Heavy Hail'
    }.each do |code, expected_description|
      it "maps code #{code} to '#{expected_description}'" do
        expect(described_class.description(code)).to eq expected_description
      end
    end

    it 'accepts a string code' do
      expect(described_class.description('0')).to eq 'Clear Sky'
    end

    it "returns 'Unknown' for an unmapped code" do
      expect(described_class.description(999)).to eq 'Unknown'
    end

    it "returns 'Unknown' for nil-like input" do
      expect(described_class.description(nil)).to eq 'Unknown'
    end
  end
end

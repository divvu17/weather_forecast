# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyForecast do
  subject(:day) do
    described_class.new(
      date:      Date.new(2026, 5, 10),
      high_temp: 81.4,
      low_temp:  59.7,
      condition: 'Slight Rain'
    )
  end

  describe 'attribute readers' do
    it 'stores the date' do
      expect(day.date).to eq Date.new(2026, 5, 10)
    end

    it 'rounds high_temp to the nearest integer' do
      expect(day.high_temp).to eq 81
    end

    it 'rounds low_temp to the nearest integer' do
      expect(day.low_temp).to eq 60
    end

    it 'stores the condition string' do
      expect(day.condition).to eq 'Slight Rain'
    end
  end
end

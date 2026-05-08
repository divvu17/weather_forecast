# frozen_string_literal: true

FactoryBot.define do
  # ── Location ───────────────────────────────────────────────────────────────
  factory :location do
    address      { '1600 Pennsylvania Ave NW, Washington, DC 20500' }
    zip_code     { '20500' }
    city         { 'Washington' }
    state        { 'District of Columbia' }
    latitude     { 38.8976 }
    longitude    { -77.0366 }
    display_name { '1600 Pennsylvania Ave NW, Washington, DC 20500, USA' }

    initialize_with do
      new(
        address:      address,
        zip_code:     zip_code,
        city:         city,
        state:        state,
        latitude:     latitude,
        longitude:    longitude,
        display_name: display_name
      )
    end

    skip_create  # PORO – not persisted to a database
  end

  # ── DailyForecast ──────────────────────────────────────────────────────────
  factory :daily_forecast do
    date      { Date.today + 1 }
    high_temp { 75 }
    low_temp  { 58 }
    condition { 'Partly Cloudy' }

    initialize_with do
      new(date: date, high_temp: high_temp, low_temp: low_temp, condition: condition)
    end

    skip_create
  end

  # ── Forecast ───────────────────────────────────────────────────────────────
  factory :forecast do
    association :location
    current_temp      { 68 }
    feels_like        { 65 }
    high_temp         { 74 }
    low_temp          { 55 }
    condition         { 'Partly Cloudy' }
    extended_forecast { build_list(:daily_forecast, 6) }
    cached            { false }
    stale             { false }

    initialize_with do
      new(
        location:          location,
        current_temp:      current_temp,
        feels_like:        feels_like,
        high_temp:         high_temp,
        low_temp:          low_temp,
        condition:         condition,
        extended_forecast: extended_forecast,
        cached:            cached,
        stale:             stale
      )
    end

    skip_create

    # Trait for a cache-hit scenario
    trait :cached do
      cached { true }
    end

    trait :stale do
      stale { true }
    end
  end
end

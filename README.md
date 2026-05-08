# Weather Forecast Application

A Ruby on Rails web application that accepts a street address, geocodes it to
retrieve coordinates and zip code, fetches current and extended weather
forecast data, and caches results by zip code for 30 minutes.

---

## Table of Contents

1. [Features](#features)
2. [Architecture & Object Decomposition](#architecture--object-decomposition)
3. [Design Patterns](#design-patterns)
4. [Technology Stack](#technology-stack)
5. [Prerequisites](#prerequisites)
6. [Setup & Installation](#setup--installation)
7. [Running the Application](#running-the-application)
8. [Running the Tests](#running-the-tests)
9. [Configuration](#configuration)
10. [Scalability Considerations](#scalability-considerations)
11. [Project Structure](#project-structure)

---

## Features

- **Address input** — accepts any US street address (full address, city/state, or zip code).
- **Current conditions** — displays current temperature, feels-like temperature, today's high/low, and a plain-English condition description.
- **Extended forecast** — 6-day outlook with daily high/low temperatures and conditions.
- **30-minute cache** — results are cached per zip code. A visible banner indicates when a result is served from cache.
- **Zero external API keys required** — uses [Nominatim (OpenStreetMap)](https://nominatim.openstreetmap.org/) for geocoding and [Open-Meteo](https://open-meteo.com/) for weather data; both are free and require no registration.

---

## Architecture & Object Decomposition

### Models (Plain Old Ruby Objects — no database)

| Class | Responsibility |
|---|---|
| `Location` | Value object. Holds the geocoded result: raw address, zip code, city, state, latitude, longitude, and display name. Immutable after construction. |
| `Forecast` | Value object. Aggregates all weather data for a location: current temperature, feels-like, today's high/low, condition, extended forecast array, and a `cached?` boolean flag. |
| `DailyForecast` | Value object. Represents a single day in the extended forecast: date, high temp, low temp, condition. Used as elements of `Forecast#extended_forecast`. |

### Services

| Class | Responsibility |
|---|---|
| `GeocodingService` | Converts a raw address string into a `Location` by calling the Nominatim geocoding API. Raises typed exceptions (`AddressNotFoundError`, `GeocodingError`) for failure cases. |
| `WeatherApiClient` | Thin HTTP wrapper around the Open-Meteo API. Accepts latitude/longitude, returns a raw parsed-JSON hash. Raises `WeatherApiError` on non-success responses. |
| `WmoWeatherCodeMapper` | Stateless utility. Maps integer WMO weather interpretation codes (returned by Open-Meteo) to human-readable English descriptions. |
| `ForecastService` | Orchestration facade. Coordinates all steps: geocoding → cache check → weather API call → object construction → cache write. Returns a `Forecast`. Translates all upstream exceptions into a single `ForecastError`. |

### Controller

| Class | Responsibility |
|---|---|
| `ForecastsController` | Thin Rails controller. `#index` renders the search form. `#show` accepts the `address` param, delegates entirely to `ForecastService`, and renders the result or re-renders the form with an error message. |

---

## Design Patterns

- **Facade** (`ForecastService`) — provides a single simple interface (`ForecastService.call(address)`) that hides the complexity of geocoding, caching, and weather retrieval from the controller.
- **Command / Service Object** — each service class exposes a single `.call` factory method. State is scoped to one request; no global mutation.
- **Value Object** (`Location`, `Forecast`, `DailyForecast`) — immutable objects that carry data without behaviour beyond simple accessors and guard predicates. Safe to cache with Rails' marshal-based file store.
- **Template Method** (implicit in `ForecastService`) — `#call` defines the algorithm skeleton; private helpers (`#geocode_address`, `#fetch_forecast_for`, etc.) implement each step independently.

---

## Technology Stack

| Component | Technology |
|---|---|
| Framework | Ruby on Rails 7.1 (no ActiveRecord — no database needed) |
| Web server | Puma 6 |
| Geocoding API | Nominatim / OpenStreetMap (free, no key) |
| Weather API | Open-Meteo (free, no key) |
| HTTP client | HTTParty |
| Cache store | File store (`tmp/cache/`) — swap for Redis/Memcached in production |
| Testing | RSpec-Rails, FactoryBot, WebMock, Shoulda-Matchers |
| UI | Bootstrap 5.3 via CDN |

---

## Prerequisites

- Ruby 3.2.x (`rbenv` or `rvm` recommended)
- Bundler 2.x (`gem install bundler`)
- No database required
- Internet access at runtime (for Nominatim and Open-Meteo API calls)

---

## Setup & Installation

```bash
# 1. Clone the repository
git clone <your-repo-url> weather_forecast
cd weather_forecast

# 2. Install Ruby dependencies
bundle install

# 3. Create the tmp/cache directory used by the file store
mkdir -p tmp/cache
```

---

## Running the Application

```bash
# Start the development server on http://localhost:3000
bundle exec rails server
```

Open your browser at [http://localhost:3000](http://localhost:3000), enter a US
address, and click **Get Forecast**.

---

## Running the Tests

```bash
# Run the full test suite
bundle exec rspec

# Run a specific spec file
bundle exec rspec spec/services/forecast_service_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```

All tests use **WebMock** to stub external HTTP calls — no real API requests
are made during the test suite.

---

## Configuration

### Cache store

The default cache store is the Rails file store (`tmp/cache/`).  For production
deployments with multiple web processes, swap this for a shared store in
`config/environments/production.rb`:

```ruby
# Redis example
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }

# Memcached example
config.cache_store = :mem_cache_store, ENV['MEMCACHEDCLOUD_SERVERS'].split(',')
```

### Cache TTL

The 30-minute TTL is defined as a constant in `ForecastService`:

```ruby
CACHE_TTL = 30.minutes
```

Change this value to adjust the cache expiration.

---

## Scalability Considerations

- **Cache store** — the file store is suitable for a single-server deployment. In a multi-server or containerised environment, replace it with Redis or Memcached so all instances share one cache and the 30-minute TTL is respected globally.
- **Rate limiting** — Nominatim enforces 1 request/second. For high traffic, consider self-hosting a Nominatim instance or switching to a commercial geocoding provider (Google Maps, Mapbox). The `GeocodingService` is the only place that needs changing.
- **API client extraction** — `WeatherApiClient` and `GeocodingService` are independently replaceable. Adding a new weather or geocoding provider requires only a new service class implementing the same interface; `ForecastService` needs no changes.
- **Horizontal scaling** — because no server-side session state is used, the app is stateless and can run behind a load balancer without sticky sessions.
- **Background jobs** — for very high traffic, pre-warming the cache via a background job (e.g. Sidekiq) for popular zip codes could reduce p99 latency for cache-miss requests.

---

## Project Structure

```
weather_forecast/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   └── forecasts_controller.rb      # GET / and GET /forecast
│   ├── models/
│   │   ├── daily_forecast.rb            # PORO: one extended forecast day
│   │   ├── forecast.rb                  # PORO: full forecast aggregate
│   │   └── location.rb                  # PORO: geocoded address
│   ├── services/
│   │   ├── forecast_service.rb          # Facade / orchestrator
│   │   ├── geocoding_service.rb         # Nominatim API wrapper
│   │   ├── weather_api_client.rb        # Open-Meteo API wrapper
│   │   └── wmo_weather_code_mapper.rb   # WMO code → description utility
│   └── views/
│       ├── layouts/application.html.erb
│       └── forecasts/
│           ├── index.html.erb           # Search form
│           └── show.html.erb            # Forecast result
├── config/
│   ├── application.rb
│   ├── boot.rb
│   ├── environment.rb
│   ├── routes.rb
│   └── environments/
│       ├── development.rb
│       ├── production.rb
│       └── test.rb
├── spec/
│   ├── controllers/
│   │   └── forecasts_controller_spec.rb
│   ├── models/
│   │   ├── daily_forecast_spec.rb
│   │   ├── forecast_spec.rb
│   │   └── location_spec.rb
│   ├── services/
│   │   ├── forecast_service_spec.rb
│   │   ├── geocoding_service_spec.rb
│   │   ├── weather_api_client_spec.rb
│   │   └── wmo_weather_code_mapper_spec.rb
│   ├── factories.rb
│   ├── rails_helper.rb
│   └── spec_helper.rb
├── Gemfile
├── Rakefile
├── config.ru
└── README.md
```

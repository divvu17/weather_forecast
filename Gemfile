# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "2.7.3"

# Core Rails framework (selective – no ActiveRecord needed; no database used)
gem "rails", "~> 7.1"

# Rack-compatible web server
gem "puma", "~> 6.0"

gem 'tzinfo-data'

# HTTP client used for Nominatim geocoding and Open-Meteo weather API calls
gem "httparty", "~> 0.21"

# Reduces boot times through caching; required false so it is loaded explicitly
gem "bootsnap", require: false

group :development do
  # In-browser REPL for debug pages
  gem "web-console"
end

group :development, :test do
  # RSpec testing framework for Rails
  gem "rspec-rails", "~> 6.1"

  # Object factories for test data
  gem "factory_bot_rails", "~> 6.2"

  # Fake data generator (names, addresses, etc.)
  gem "faker", "~> 3.2"

  # Stub / mock external HTTP calls so tests never hit real APIs
  gem "webmock", "~> 3.23"

  # Fluent matchers for ActiveModel-style objects
  gem "shoulda-matchers", "~> 5.3"
end

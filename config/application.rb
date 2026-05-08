# frozen_string_literal: true

require_relative 'boot'

# Load only the Rails railties we actually need.
# Deliberately excludes ActiveRecord (no database) and ActionMailer.
require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rails/test_unit/railtie'

# Load all gems declared in the Gemfile for the current environment
Bundler.require(*Rails.groups)

module WeatherForecast
  # ===========================================================================
  # WeatherForecast::Application
  #
  # Top-level Rails application class.  Configures the framework without any
  # database layer – all persistence is handled via Rails.cache (file store).
  # ===========================================================================
  class Application < Rails::Application
    config.load_defaults 7.1

    # ---------------------------------------------------------------------------
    # Timezone
    # ---------------------------------------------------------------------------
    config.time_zone = 'Eastern Time (US & Canada)'

    # ---------------------------------------------------------------------------
    # Cache store
    #
    # File store keeps cached forecasts across server restarts and requires no
    # external services (Redis, Memcached, etc.).  The 30-minute TTL is enforced
    # at the call site in ForecastService.
    # ---------------------------------------------------------------------------
    config.cache_store = :file_store, Rails.root.join('tmp', 'cache')

    # Ensure Rails.cache is usable in all environments (action caching is not
    # required; we call Rails.cache directly from the service layer).
    config.action_controller.perform_caching = true

    # ---------------------------------------------------------------------------
    # Generator preferences
    # ---------------------------------------------------------------------------
    config.generators do |g|
      g.test_framework :rspec
      g.helper        false
      g.assets        false
    end
  end
end

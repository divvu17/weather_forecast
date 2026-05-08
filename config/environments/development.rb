# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # --- Debugging / Reloading ---------------------------------------------------
  config.enable_reloading = true
  config.eager_load        = false
  config.consider_all_requests_local = true

  # --- Cache -------------------------------------------------------------------
  # Keep file store in development so we can test the 30-minute cache behaviour
  # without additional infrastructure.  Run `rails dev:cache` to toggle if needed.
  config.action_controller.perform_caching = true
  config.cache_store = :file_store, Rails.root.join('tmp', 'cache')

  # --- Logging -----------------------------------------------------------------
  config.log_level = :debug
  config.log_formatter = ::Logger::Formatter.new

  # --- Assets ------------------------------------------------------------------
  config.assets.debug   = true if config.respond_to?(:assets)
  config.assets.quiet   = true if config.respond_to?(:assets)
end

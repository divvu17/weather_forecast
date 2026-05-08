# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading             = false
  config.eager_load                   = false
  config.consider_all_requests_local  = true

  # Use an in-memory store for tests: fast, isolated, and cleared between runs.
  config.cache_store = :memory_store
  config.action_controller.perform_caching = true
end

# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load       = true
  config.consider_all_requests_local = false
  config.log_level        = :info
  config.force_ssl        = true

  # Use file store in production; swap for :mem_cache_store or :redis_cache_store
  # if a distributed cache is available in the deployment environment.
  config.cache_store = :file_store, Rails.root.join('tmp', 'cache')
  config.action_controller.perform_caching = true
end

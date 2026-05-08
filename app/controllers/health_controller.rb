# frozen_string_literal: true

class HealthController < ApplicationController
  # Lightweight liveness endpoint for load balancers.
  def show
    render json: { status: 'ok', timestamp: Time.current.iso8601 }, status: :ok
  end

  # Dependency checks that do not call external APIs.
  # Validates cache read/write round-trip and reports status.
  def dependencies
    cache_key = "health/cache/#{request.request_id}"
    value = Time.current.to_f

    Rails.cache.write(cache_key, value, expires_in: 1.minute)
    cache_ok = Rails.cache.read(cache_key) == value

    status = cache_ok ? :ok : :service_unavailable
    render json: {
      status: cache_ok ? 'ok' : 'degraded',
      dependencies: {
        cache: cache_ok ? 'ok' : 'unavailable'
      }
    }, status: status
  rescue StandardError => e
    render json: {
      status: 'degraded',
      dependencies: {
        cache: 'unavailable'
      },
      error: e.class.name
    }, status: :service_unavailable
  end
end

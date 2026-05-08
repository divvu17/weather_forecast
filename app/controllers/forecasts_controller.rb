# frozen_string_literal: true

# =============================================================================
# ForecastsController
#
# Handles the two user-facing interactions:
#
#   GET /          → #index  : renders the address search form
#   GET /forecast  → #show   : geocodes address, retrieves forecast, renders result
#
# Design notes:
#   - The controller is intentionally thin; all business logic lives in
#     ForecastService.  The controller's responsibility is limited to HTTP
#     parameter handling, delegation, and choosing the response.
#   - ForecastService::ForecastError is the single exception type the
#     controller needs to handle; it covers both geocoding and weather failures.
#   - On error the controller re-renders the index form with @error set,
#     allowing the view to display the user-friendly message.
# =============================================================================
class ForecastsController < ApplicationController
  # GET /
  #
  # Renders the address search form.  No data required.
  def index; end

  # GET /forecast?address=<user input>
  #
  # Delegates to ForecastService and assigns @forecast for the view.
  # Redirects back to the form with an alert if the address param is missing,
  # and re-renders the index with @error set if the service raises.
  def show
    address = params[:address].to_s.strip

    if address.blank?
      redirect_to root_path, alert: 'Please enter an address.'
      return
    end

    Rails.logger.info({ event: 'forecast.request', address: address, request_id: request.request_id }.to_json)
    @forecast = ForecastService.call(address)
    Rails.logger.info(
      {
        event: 'forecast.success',
        address: address,
        request_id: request.request_id,
        cached: @forecast.cached?,
        stale: @forecast.stale?
      }.to_json
    )
  rescue ForecastService::ForecastError => e
    Rails.logger.warn(
      {
        event: 'forecast.failure',
        address: address,
        request_id: request.request_id,
        error: e.message
      }.to_json
    )
    @error = e.message
    render :index
  end
end

# frozen_string_literal: true

Rails.application.routes.draw do
  # Health endpoints for deployment and runtime checks
  get '/health', to: 'health#show'
  get '/health/dependencies', to: 'health#dependencies'

  # Root displays the address search form
  root 'forecasts#index'

  # GET /forecast?address=<user input>
  # Returns the weather forecast for the given address
  get '/forecast', to: 'forecasts#show', as: :forecast
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForecastsController, type: :controller do
  render_views

  let(:forecast)  { build(:forecast) }
  let(:address)   { '1600 Pennsylvania Ave, Washington, DC' }

  # ── GET / (index) ──────────────────────────────────────────────────────────

  describe 'GET #index' do
    it 'responds with 200 OK' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'renders the search form content' do
      get :index
      expect(response.body).to include('Get Your Forecast')
    end
  end

  # ── GET /forecast (show – success) ────────────────────────────────────────

  describe 'GET #show with a valid address' do
    before do
      allow(ForecastService).to receive(:call).with(address).and_return(forecast)
      get :show, params: { address: address }
    end

    it 'responds with 200 OK' do
      expect(response).to have_http_status(:ok)
    end

    it 'renders forecast data in the response body' do
      expect(response.body).to include('6-Day Forecast')
    end

    it 'delegates to ForecastService' do
      expect(ForecastService).to have_received(:call).with(address)
    end
  end

  # ── GET /forecast with blank address ──────────────────────────────────────

  describe 'GET #show with a blank address' do
    it 'redirects to root with an alert' do
      get :show, params: { address: '' }
      expect(response).to redirect_to(root_path)
    end

    it 'does not call ForecastService' do
      allow(ForecastService).to receive(:call)
      get :show, params: { address: '' }
      expect(ForecastService).not_to have_received(:call)
    end
  end

  # ── GET /forecast with missing address param ───────────────────────────────

  describe 'GET #show with no address param' do
    it 'redirects to root' do
      get :show
      expect(response).to redirect_to(root_path)
    end
  end

  # ── GET /forecast when ForecastService raises ─────────────────────────────

  describe 'GET #show when ForecastService raises ForecastError' do
    before do
      allow(ForecastService).to receive(:call)
        .and_raise(ForecastService::ForecastError, 'Address not found')
      get :show, params: { address: address }
    end

    it 'renders the error message to the user' do
      expect(response.body).to include('Address not found')
    end
  end
end

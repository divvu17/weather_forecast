# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe 'GET #show' do
    it 'returns 200' do
      get :show
      expect(response).to have_http_status(:ok)
    end

    it 'returns ok status in JSON' do
      get :show
      body = JSON.parse(response.body)
      expect(body['status']).to eq 'ok'
    end
  end

  describe 'GET #dependencies' do
    it 'returns 200 when cache read/write is healthy' do
      get :dependencies
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['status']).to eq 'ok'
      expect(body.dig('dependencies', 'cache')).to eq 'ok'
    end

    it 'returns 503 when cache raises' do
      allow(Rails.cache).to receive(:write).and_raise(StandardError)

      get :dependencies
      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body['status']).to eq 'degraded'
    end
  end
end

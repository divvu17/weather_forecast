# frozen_string_literal: true

# Load the Rails application environment before any spec
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rspec/rails'

# Prevent any spec from making real HTTP requests.
# If a spec intentionally needs to hit the network, use WebMock.allow_net_connect!
# or VCR.
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Use FactoryBot methods without the FactoryBot. prefix
  config.include FactoryBot::Syntax::Methods

  # Reset the cache between each example so no state leaks across tests
  config.before(:each) do
    Rails.cache.clear
  end

  # Run specs in random order to catch order-dependent failures
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

# Shoulda-Matchers integration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library        :rails
  end
end

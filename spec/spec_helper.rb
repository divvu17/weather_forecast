# frozen_string_literal: true

# This file is loaded by RSpec before any test.  It does NOT load Rails; use
# rails_helper.rb for tests that need the application context.
RSpec.configure do |config|
  # Use the documented expect() syntax exclusively
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Use the new message-expectation syntax
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

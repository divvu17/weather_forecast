ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup'      # Set up gems listed in the Gemfile
require 'bootsnap/setup' rescue nil  # Speed up boot time; skip gracefully if unavailable

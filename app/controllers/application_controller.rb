# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Protect all forms from CSRF attacks using the standard Rails token strategy
  protect_from_forgery with: :exception
end

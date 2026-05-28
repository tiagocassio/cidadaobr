# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authenticatable

  allow_browser versions: :modern
end

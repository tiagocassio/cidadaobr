# frozen_string_literal: true

module Web
  class BaseController < ApplicationController
    include Authorizable

    layout "web"
    before_action :authenticate!
  end
end

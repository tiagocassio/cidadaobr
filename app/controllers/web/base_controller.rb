# frozen_string_literal: true

module Web
  class BaseController < ApplicationController
    include Authorizable
    include TenantRlsRequestScope

    helper Web::FcdFormHelper

    layout "web"
    before_action :authenticate!
  end
end

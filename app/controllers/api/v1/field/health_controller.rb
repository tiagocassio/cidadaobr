# frozen_string_literal: true

module Api
  module V1
    module Field
      class HealthController < Api::ApplicationController
        include Api::V1::HealthCheck

        health_channel "field"
      end
    end
  end
end

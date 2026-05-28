# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class HealthController < Api::ApplicationController
        include Api::V1::HealthCheck

        health_channel "citizen"
      end
    end
  end
end

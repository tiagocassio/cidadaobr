# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class HealthController < ActionController::API
        def show
          render json: { status: "ok", channel: "citizen" }
        end
      end
    end
  end
end

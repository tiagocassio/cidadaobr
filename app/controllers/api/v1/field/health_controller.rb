# frozen_string_literal: true

module Api
  module V1
    module Field
      class HealthController < ActionController::API
        def show
          render json: { status: "ok", channel: "field" }
        end
      end
    end
  end
end

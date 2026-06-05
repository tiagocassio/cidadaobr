# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class PanicAlertsController < BaseController
        def create
          alert = CommandBus.dispatch(
            CitizenPortal::Commands::TriggerPanicAlert,
            latitude: params[:latitude],
            longitude: params[:longitude],
            citizen_account: current_citizen_account
          )
          @panic_alert = alert
        rescue ArgumentError => e
          render_json_error(e.message, status: :unprocessable_entity)
        end
      end
    end
  end
end

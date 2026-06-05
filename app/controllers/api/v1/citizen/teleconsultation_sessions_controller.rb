# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class TeleconsultationSessionsController < BaseController
        def index
          @sessions = TeleconsultationSession
            .where(citizen_id: current_citizen.id)
            .order(scheduled_at: :desc)
            .limit(20)
        end

        def create
          @session = CommandBus.dispatch(
            CitizenPortal::Commands::CreateTeleconsultationSession,
            scheduled_at: parse_time!(params.require(:scheduled_at)),
            appointment_id: params[:appointment_id],
            room_token: params[:room_token]
          )
        rescue ArgumentError => e
          render_json_error(e.message, status: :unprocessable_entity)
        rescue ActiveRecord::RecordInvalid => e
          render_json_error(e.record.errors.full_messages.to_sentence, status: :unprocessable_entity)
        end

        private

        def parse_time!(value)
          Time.zone.parse(value.to_s) || raise(ArgumentError, "invalid scheduled_at")
        rescue ArgumentError, TypeError
          raise ArgumentError, "invalid scheduled_at"
        end
      end
    end
  end
end

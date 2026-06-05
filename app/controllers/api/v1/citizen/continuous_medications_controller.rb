# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class ContinuousMedicationsController < BaseController
        def index
          @medications = CitizenContinuousMedication
            .where(citizen_id: current_citizen.id, active: true)
            .order(started_on: :desc)
        end

        def create
          @medication = CommandBus.dispatch(
            CitizenPortal::Commands::RegisterContinuousMedication,
            medication_name: params.require(:medication_name),
            dosage: params[:dosage],
            frequency: params[:frequency],
            started_on: params[:started_on].presence && Date.parse(params[:started_on].to_s)
          )
        rescue Date::Error, ArgumentError
          render_json_error("Invalid started_on date", status: :unprocessable_entity)
        rescue ActiveRecord::RecordInvalid => e
          render_json_error(e.record.errors.full_messages.to_sentence, status: :unprocessable_entity)
        end
      end
    end
  end
end

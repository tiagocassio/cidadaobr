# frozen_string_literal: true

module Scheduling
  class CompleteAppointment < ApplicationCommand
    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      raise Scheduling::Errors::InvalidTransitionError unless @appointment.status.in?(%w[checked_in in_progress])

      tenant = Cidadaobr::TenantContext.current_or_raise!

      write_transaction do
        @appointment.update!(status: "completed")

        encounter = Encounter.create!(
          municipality_id: tenant.municipality_id,
          health_facility_id: @appointment.health_facility_id,
          care_team_id: @appointment.care_team_id,
          citizen_id: @appointment.citizen_id,
          appointment_id: @appointment.id,
          record_type: map_record_type(@appointment.appointment_service_type.code),
          encounter_at: Time.current
        )

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::APPOINTMENT_COMPLETED,
          aggregate_type: "Appointment",
          aggregate_id: @appointment.id,
          payload: {
            appointment_id: @appointment.id,
            encounter_id: encounter.id
          },
          care_team_id: @appointment.care_team_id
        )

        encounter
      end
    end

    private

    def map_record_type(service_code)
      case service_code
      when "dental" then "FAO"
      when "procedure" then "FP"
      when "immunization", "animal_vaccination" then "FV"
      else "FAI"
      end
    end
  end
end

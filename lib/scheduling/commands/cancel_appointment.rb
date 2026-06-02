# frozen_string_literal: true

module Scheduling
  class CancelAppointment < ApplicationCommand
    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      # Absences after check-in use MarkAppointmentNoShow (no_show), not cancel.
      raise Scheduling::Errors::InvalidTransitionError unless @appointment.status.in?(%w[scheduled confirmed])

      write_transaction do
        @appointment.update!(status: "cancelled")
        SlotRelease.release_appointment_slot!(@appointment)

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::APPOINTMENT_CANCELLED,
          aggregate_type: "Appointment",
          aggregate_id: @appointment.id,
          payload: {
            appointment_id: @appointment.id,
            citizen_id: @appointment.citizen_id,
            status: @appointment.status
          },
          care_team_id: @appointment.care_team_id
        )

        @appointment
      end
    end

  end
end

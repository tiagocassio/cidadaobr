# frozen_string_literal: true

module Scheduling
  class MarkAppointmentNoShow < ApplicationCommand
    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      raise Scheduling::Errors::InvalidTransitionError unless @appointment.status.in?(%w[scheduled confirmed checked_in in_progress])

      write_transaction do
        @appointment.update!(status: "no_show")
        SlotRelease.release_appointment_slot!(@appointment)

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::APPOINTMENT_NOSHOW,
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

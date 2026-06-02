# frozen_string_literal: true

module Scheduling
  class CheckInAppointment < ApplicationCommand
    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      raise Scheduling::Errors::InvalidTransitionError unless @appointment.status.in?(%w[scheduled confirmed])

      write_transaction do
        @appointment.update!(status: "checked_in")

        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::APPOINTMENT_CHECKEDIN,
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

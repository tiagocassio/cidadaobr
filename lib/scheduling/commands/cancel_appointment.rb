# frozen_string_literal: true

module Scheduling
  class CancelAppointment < ApplicationCommand
    def initialize(appointment:)
      @appointment = appointment
    end

    def call
      # checked_in allowed so reception can cancel no-shows after check-in without completing visit.
      raise Scheduling::Errors::InvalidTransitionError unless @appointment.status.in?(%w[scheduled confirmed checked_in])

      ActiveRecord::Base.transaction do
        @appointment.update!(status: "cancelled")
        release_slot!(@appointment)

        RecordPlatformEvent.call(
          event_type: "appointment.cancelled",
          aggregate_type: "Appointment",
          aggregate_id: @appointment.id,
          payload: {
            appointment_id: @appointment.id,
            citizen_id: @appointment.citizen_id,
            status: @appointment.status
          },
          topic: OutboxPublisher::TOPIC_MAPPING.fetch("appointment.cancelled"),
          care_team_id: @appointment.care_team_id
        )

        @appointment
      end
    end

    private

    def release_slot!(appointment)
      room_slot = appointment.appointment_room_slot
      return unless room_slot

      capacity_slot_id = room_slot.room_capacity_slot_id
      SlotCapacity.release!(capacity_slot_id)
      room_slot.destroy!
    end
  end
end

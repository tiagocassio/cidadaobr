# frozen_string_literal: true

# Command for EPIC-03 follow-up; not exposed on web/API routes yet.
module Scheduling
  class RescheduleAppointment < ApplicationCommand
    def initialize(appointment:, scheduled_at:, room_capacity_slot_id:)
      @appointment = appointment
      @scheduled_at = scheduled_at
      @room_capacity_slot_id = room_capacity_slot_id
    end

    def call
      raise Scheduling::Errors::InvalidTransitionError unless @appointment.status.in?(%w[scheduled confirmed])

      tenant = Cidadaobr::TenantContext.current_or_raise!

      ActiveRecord::Base.transaction do
        capacity_slot = SlotCapacity.find_for_booking!(@room_capacity_slot_id)
        validate_reschedule_slot!(@appointment, capacity_slot)
        @scheduled_at = BookingGuards.coerce_scheduled_at_for_slot!(@scheduled_at, capacity_slot)

        current_slot_id = @appointment.appointment_room_slot&.room_capacity_slot_id
        same_slot = capacity_slot.id == current_slot_id

        unless same_slot
          SlotCapacity.reserve!(capacity_slot.id)
          release_slot!(@appointment)

          AppointmentRoomSlot.create!(
            municipality_id: tenant.municipality_id,
            health_facility_id: @appointment.health_facility_id,
            room_capacity_slot: capacity_slot,
            appointment: @appointment,
            status: "reserved"
          )
        end

        @appointment.update!(scheduled_at: @scheduled_at, status: "scheduled")

        RecordPlatformEvent.call(
          event_type: "appointment.rescheduled",
          aggregate_type: "Appointment",
          aggregate_id: @appointment.id,
          payload: {
            appointment_id: @appointment.id,
            citizen_id: @appointment.citizen_id,
            scheduled_at: @appointment.scheduled_at.iso8601,
            room_capacity_slot_id: capacity_slot.id
          },
          topic: OutboxPublisher::TOPIC_MAPPING.fetch("appointment.rescheduled"),
          care_team_id: @appointment.care_team_id
        )

        @appointment
      end
    end

    private

    def validate_reschedule_slot!(appointment, capacity_slot)
      if capacity_slot.municipality_id != appointment.municipality_id ||
         capacity_slot.health_facility_id != appointment.health_facility_id ||
         capacity_slot.consultation_room_id != appointment.consultation_room_id
        raise Scheduling::Errors::SlotUnavailableError, "Slot does not belong to this appointment"
      end
    end

    def release_slot!(appointment)
      room_slot = appointment.appointment_room_slot
      return unless room_slot

      capacity_slot_id = room_slot.room_capacity_slot_id
      SlotCapacity.release!(capacity_slot_id)
      room_slot.destroy!
    end
  end
end

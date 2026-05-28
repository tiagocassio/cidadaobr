# frozen_string_literal: true

module Scheduling
  class FacilityDailySchedule
    def initialize(health_facility_id:, date: Date.current)
      @health_facility_id = health_facility_id
      @date = date.to_date
    end

    def call
      appointments = Appointment
        .includes(:citizen, :consultation_room, :appointment_service_type)
        .where(health_facility_id: @health_facility_id, scheduled_at: @date.all_day)
        .order(:scheduled_at)

      slots = RoomCapacitySlot
        .includes(:consultation_room, :appointment_room_slots)
        .where(health_facility_id: @health_facility_id, slot_date: @date)
        .order(:starts_at)

      {
        date: @date,
        appointments: appointments,
        capacity_slots: slots
      }
    end
  end
end

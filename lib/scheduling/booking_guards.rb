# frozen_string_literal: true

module Scheduling
  module BookingGuards
    module_function

    def scheduled_at_for_slot(slot)
      Time.zone.parse("#{slot.slot_date} #{slot.starts_at.strftime('%H:%M:%S')}")
    end

    def validate_scheduled_at_matches!(scheduled_at, slot)
      expected = scheduled_at_for_slot(slot)
      actual = scheduled_at.in_time_zone
      return if actual.change(sec: 0) == expected.change(sec: 0)

      Scheduling::Errors::SlotUnavailableError.raise!(:slot_time_mismatch)
    end

    def coerce_scheduled_at_for_slot!(scheduled_at, slot)
      validate_scheduled_at_matches!(scheduled_at, slot)
      scheduled_at_for_slot(slot)
    end

    def validate_room_slot_coherence!(room, capacity_slot)
      if capacity_slot.consultation_room_id != room.id ||
         capacity_slot.health_facility_id != room.health_facility_id
        Scheduling::Errors::SlotUnavailableError.raise!(:slot_room_mismatch)
      end
    end
  end
end

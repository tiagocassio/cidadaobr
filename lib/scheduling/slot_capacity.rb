# frozen_string_literal: true

module Scheduling
  module SlotCapacity
    module_function

    # Citizens cannot SELECT FOR UPDATE under RLS until a reserved appointment_room_slot exists;
    # staff scopes use row locks, citizens rely on atomic reserve!/release!.
    def find_for_booking!(slot_id)
      raise Scheduling::Errors::SlotUnavailableError, "Slot not found" if slot_id.blank?

      scope = RoomCapacitySlot
      scope = scope.lock unless citizen_booking_scope?
      scope.find(slot_id)
    rescue ActiveRecord::RecordNotFound
      raise Scheduling::Errors::SlotUnavailableError, "Slot not found"
    end

    def citizen_booking_scope?
      Cidadaobr::TenantContext.current&.scope == "citizen"
    end

    # Authoritative capacity is SQL-side via update_all; AR instances may be stale.
    def reserve!(capacity_slot_id)
      reserved = RoomCapacitySlot.where(id: capacity_slot_id)
        .where("booked_count < capacity")
        .update_all("booked_count = booked_count + 1")
      return if reserved.positive?

      raise Scheduling::Errors::SlotUnavailableError, "No capacity remaining for slot"
    end

    def release!(capacity_slot_id)
      released = RoomCapacitySlot.where(id: capacity_slot_id)
        .where("booked_count > 0")
        .update_all("booked_count = booked_count - 1")
      return if released.positive?

      raise Scheduling::Errors::SlotUnavailableError, "Could not release slot capacity"
    end
  end
end

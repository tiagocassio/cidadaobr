# frozen_string_literal: true

module Scheduling
  module SlotRelease
    module_function

    def release_appointment_slot!(appointment)
      room_slot = appointment.appointment_room_slot
      return unless room_slot

      SlotCapacity.release!(room_slot.room_capacity_slot_id)
      room_slot.destroy!
    end
  end
end

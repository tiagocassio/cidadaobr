# frozen_string_literal: true

class CreateAppointmentRoomSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_room_slots, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :room_capacity_slot_id, null: false
      t.uuid :appointment_id
      t.string :status, null: false, default: "available"
      t.timestamps
    end
    add_index :appointment_room_slots, :room_capacity_slot_id
    add_index :appointment_room_slots, :appointment_id, unique: true, where: "appointment_id IS NOT NULL"
  end
end

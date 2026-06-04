# frozen_string_literal: true

class CreateRoomCapacitySlots < ActiveRecord::Migration[8.1]
  def change
    create_table :room_capacity_slots, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :consultation_room_id, null: false
      t.date :slot_date, null: false
      t.time :starts_at, null: false
      t.time :ends_at, null: false
      t.integer :capacity, null: false, default: 1
      t.integer :booked_count, null: false, default: 0
      t.timestamps
    end
    add_index :room_capacity_slots, %i[consultation_room_id slot_date starts_at], unique: true, name: "index_room_capacity_slots_on_room_date_start"
  end
end

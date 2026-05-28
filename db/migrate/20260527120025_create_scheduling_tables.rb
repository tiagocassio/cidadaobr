# frozen_string_literal: true

class CreateSchedulingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :consultation_rooms, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.string :name, null: false
      t.string :room_kind, null: false, default: "general"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :consultation_rooms, %i[municipality_id health_facility_id name], unique: true, name: "index_consultation_rooms_on_facility_and_name"

    create_table :appointment_service_types, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.integer :default_duration_minutes, null: false, default: 20
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :appointment_service_types, %i[municipality_id code], unique: true

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

    create_table :appointments, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :consultation_room_id, null: false
      t.uuid :appointment_service_type_id, null: false
      t.uuid :citizen_id, null: false
      t.uuid :care_team_id
      t.uuid :professional_id
      t.datetime :scheduled_at, null: false
      t.integer :duration_minutes, null: false, default: 20
      t.string :status, null: false, default: "scheduled"
      t.string :kind, null: false, default: "scheduled"
      t.string :channel, null: false, default: "web_reception"
      t.string :modality, null: false, default: "in_person"
      t.timestamps
    end
    add_index :appointments, %i[municipality_id scheduled_at]
    add_index :appointments, %i[health_facility_id status scheduled_at]

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

    create_table :appointment_waitlist_entries, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :appointment_service_type_id, null: false
      t.uuid :citizen_id, null: false
      t.integer :priority, null: false, default: 0
      t.string :status, null: false, default: "waiting"
      t.timestamps
    end

    create_table :professional_availability_blocks, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :professional_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason
      t.timestamps
    end

    add_reference :encounters, :appointment, type: :uuid, foreign_key: true, index: true
  end
end

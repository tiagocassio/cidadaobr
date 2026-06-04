# frozen_string_literal: true

class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
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
  end
end

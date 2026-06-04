# frozen_string_literal: true

class CreateAppointmentWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_waitlist_entries, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :appointment_service_type_id, null: false
      t.uuid :citizen_id, null: false
      t.integer :priority, null: false, default: 0
      t.string :status, null: false, default: "waiting"
      t.timestamps
    end
  end
end

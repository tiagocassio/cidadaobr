# frozen_string_literal: true

class CreateAppointmentServiceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_service_types, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.integer :default_duration_minutes, null: false, default: 20
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :appointment_service_types, %i[municipality_id code], unique: true
  end
end

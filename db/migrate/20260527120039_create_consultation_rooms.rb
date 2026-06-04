# frozen_string_literal: true

class CreateConsultationRooms < ActiveRecord::Migration[8.1]
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
  end
end

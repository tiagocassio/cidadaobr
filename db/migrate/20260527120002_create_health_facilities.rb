# frozen_string_literal: true

class CreateHealthFacilities < ActiveRecord::Migration[8.1]
  def change
    create_table :health_facilities, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :cnes, null: false
      t.string :facility_service_kind, null: false, default: "primary_care"
      t.timestamps
    end

    add_index :health_facilities, [ :municipality_id, :cnes ], unique: true
  end
end

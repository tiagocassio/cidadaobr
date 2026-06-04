# frozen_string_literal: true

class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.string :ibge_code, null: false
      t.string :micro_area_code
      t.string :street
      t.string :street_number
      t.string :complement
      t.string :neighborhood
      t.string :postal_code
      t.uuid :clinical_record_id
      t.timestamps
    end

    add_index :households, [ :municipality_id, :clinical_record_id ], unique: true, name: "index_households_on_municipality_and_clinical_record"
  end
end

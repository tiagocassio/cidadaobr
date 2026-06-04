# frozen_string_literal: true

class CreateEncounters < ActiveRecord::Migration[8.1]
  def change
    create_table :encounters, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.uuid :citizen_id
      t.uuid :clinical_record_id
      t.uuid :clinical_record_item_id
      t.string :record_type, null: false
      t.datetime :encounter_at, null: false
      t.timestamps
    end

    add_index :encounters, [ :municipality_id, :clinical_record_id, :clinical_record_item_id ], unique: true, name: "index_encounters_on_municipality_and_clinical_refs"
  end
end

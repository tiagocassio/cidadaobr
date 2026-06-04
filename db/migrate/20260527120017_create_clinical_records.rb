# frozen_string_literal: true

class CreateClinicalRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :clinical_records, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.uuid :transport_record_id, null: false
      t.string :record_type, null: false
      t.uuid :record_uuid, null: false
      t.uuid :originator_record_uuid
      t.jsonb :payload_json, null: false, default: {}
      t.string :payload_schema_version, null: false
      t.string :cnes
      t.string :ibge_code
      t.datetime :encounter_at
      t.string :professional_cns
      t.string :validation_status, null: false, default: "pending"
      t.timestamps
    end

    add_index :clinical_records, [ :municipality_id, :record_uuid ], unique: true, name: "index_clinical_records_on_municipality_and_record_uuid"
    add_index :clinical_records, :transport_record_id
    add_index :clinical_records, :record_type
  end
end

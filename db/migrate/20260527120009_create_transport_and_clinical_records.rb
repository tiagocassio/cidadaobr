# frozen_string_literal: true

class CreateTransportAndClinicalRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :transport_records, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id
      t.uuid :care_team_id
      t.uuid :ledi_batch_id
      t.uuid :origin_health_facility_id
      t.uuid :serialized_uuid, null: false
      t.bigint :serialized_type, null: false
      t.string :cnes, null: false
      t.string :ibge_code, null: false
      t.string :ine
      t.bigint :batch_number
      t.binary :payload_binary, null: false
      t.string :ledi_version, null: false
      t.string :status, null: false, default: "draft"
      t.timestamps
    end

    add_index :transport_records, [ :municipality_id, :serialized_uuid ], unique: true, name: "index_transport_records_on_municipality_and_uuid"
    add_index :transport_records, :ledi_batch_id
    add_index :transport_records, :status

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

    create_table :clinical_record_items, id: :uuid do |t|
      t.uuid :clinical_record_id, null: false
      t.integer :sequence, null: false, default: 0
      t.jsonb :payload_json, null: false, default: {}
      t.string :citizen_cpf
      t.string :citizen_cns
      t.timestamps
    end

    add_index :clinical_record_items, [ :clinical_record_id, :sequence ], unique: true, name: "index_clinical_record_items_on_record_and_sequence"
  end
end

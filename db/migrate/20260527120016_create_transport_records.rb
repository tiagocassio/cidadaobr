# frozen_string_literal: true

class CreateTransportRecords < ActiveRecord::Migration[8.1]
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
  end
end

# frozen_string_literal: true

class CreateCitizenFeatureSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :citizen_feature_snapshots, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :citizen_id
      t.uuid :clinical_record_id, null: false
      t.string :record_type, null: false
      t.string :feature_schema_version, null: false, default: "v1"
      t.jsonb :features, null: false, default: {}
      t.string :source_payload_digest
      t.datetime :computed_at, null: false
      t.timestamps
    end

    add_index :citizen_feature_snapshots,
              %i[clinical_record_id feature_schema_version],
              unique: true,
              name: "index_citizen_feature_snapshots_on_record_and_schema"
    add_index :citizen_feature_snapshots, %i[municipality_id citizen_id computed_at],
              name: "index_citizen_feature_snapshots_on_municipality_citizen_time"
    add_index :citizen_feature_snapshots, :features, using: :gin,
              name: "index_citizen_feature_snapshots_on_features"
    add_index :citizen_feature_snapshots, :computed_at, using: :brin,
              name: "index_citizen_feature_snapshots_on_computed_at"
  end
end

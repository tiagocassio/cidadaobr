# frozen_string_literal: true

class AddCitizenFeatureSnapshotForeignKeys < ActiveRecord::Migration[8.1]
  def up
    add_foreign_key :citizen_feature_snapshots, :municipalities, column: :municipality_id
    add_foreign_key :citizen_feature_snapshots, :citizens, column: :citizen_id
    add_foreign_key :citizen_feature_snapshots, :clinical_records, column: :clinical_record_id
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end

  def down
    remove_foreign_key :citizen_feature_snapshots, :clinical_records
    remove_foreign_key :citizen_feature_snapshots, :citizens
    remove_foreign_key :citizen_feature_snapshots, :municipalities
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end
end

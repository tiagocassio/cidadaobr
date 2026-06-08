# frozen_string_literal: true

# Re-applies RLS after citizen_feature_snapshots moved to municipality_only (drops retired citizen_access policy).
class RefreshCitizenFeatureSnapshotCitizenRls < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end

  def down
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end
end

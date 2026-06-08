# frozen_string_literal: true

# Applies initial municipality_only RLS for citizen_feature_snapshots via TenantRlsPolicies.ensure!
class RefreshAiFeatureRlsPolicies < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end

  def down
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end
end

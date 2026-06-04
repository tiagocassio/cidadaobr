# frozen_string_literal: true

class RefreshPhase2RlsPolicies < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end

  def down
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end
end

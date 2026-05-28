# frozen_string_literal: true

class RefreshLediRlsPolicies < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end

  def down
    # Policies are replaced idempotently by ensure!; no destructive down migration.
  end
end

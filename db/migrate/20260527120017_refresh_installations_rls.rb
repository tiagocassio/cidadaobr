# frozen_string_literal: true

class RefreshInstallationsRls < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::TenantRlsPolicies.ensure!
  end

  def down
    Cidadaobr::TenantRlsPolicies.ensure!
  end
end

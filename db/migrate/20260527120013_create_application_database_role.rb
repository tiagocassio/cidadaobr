# frozen_string_literal: true

class CreateApplicationDatabaseRole < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::DatabaseRoleSetup.ensure!(connection: connection)
  end

  def down
    execute <<~SQL
      REVOKE cidadaobr_app FROM CURRENT_USER;
      DROP ROLE IF EXISTS cidadaobr_app;
    SQL
  end
end

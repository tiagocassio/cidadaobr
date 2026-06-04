# frozen_string_literal: true

class EnableRowLevelSecurity < ActiveRecord::Migration[8.1]
  def up
    Cidadaobr::TenantRlsPolicies.ensure!(connection: connection)
  end

  def down
    execute <<~SQL
      DROP POLICY IF EXISTS outbox_messages_citizen_access ON outbox_messages;
      DROP POLICY IF EXISTS outbox_messages_facility_access ON outbox_messages;
      DROP POLICY IF EXISTS outbox_messages_team_access ON outbox_messages;
      DROP POLICY IF EXISTS outbox_messages_municipal_access ON outbox_messages;
      ALTER TABLE outbox_messages DISABLE ROW LEVEL SECURITY;

      DROP POLICY IF EXISTS domain_events_citizen_access ON domain_events;
      DROP POLICY IF EXISTS domain_events_facility_access ON domain_events;
      DROP POLICY IF EXISTS domain_events_team_access ON domain_events;
      DROP POLICY IF EXISTS domain_events_municipal_access ON domain_events;
      ALTER TABLE domain_events DISABLE ROW LEVEL SECURITY;
    SQL
  end
end

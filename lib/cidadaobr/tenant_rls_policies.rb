# frozen_string_literal: true

module Cidadaobr
  module TenantRlsPolicies
    module_function

    def ensure!(connection: ActiveRecord::Base.connection)
      connection.execute <<~SQL
        ALTER TABLE domain_events ENABLE ROW LEVEL SECURITY;
        ALTER TABLE domain_events FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS domain_events_municipal_access ON domain_events;
        CREATE POLICY domain_events_municipal_access ON domain_events
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS domain_events_team_access ON domain_events;
        CREATE POLICY domain_events_team_access ON domain_events
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND care_team_id::text = ANY(
              string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND care_team_id::text = ANY(
              string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
            )
          );

        DROP POLICY IF EXISTS domain_events_facility_access ON domain_events;
        CREATE POLICY domain_events_facility_access ON domain_events
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
          );

        DROP POLICY IF EXISTS domain_events_citizen_access ON domain_events;
        CREATE POLICY domain_events_citizen_access ON domain_events
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND aggregate_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND aggregate_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          );

        ALTER TABLE outbox_messages ENABLE ROW LEVEL SECURITY;
        ALTER TABLE outbox_messages FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS outbox_messages_municipal_access ON outbox_messages;
        CREATE POLICY outbox_messages_municipal_access ON outbox_messages
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS outbox_messages_team_access ON outbox_messages;
        CREATE POLICY outbox_messages_team_access ON outbox_messages
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND EXISTS (
              SELECT 1
              FROM domain_events de
              WHERE de.id = outbox_messages.domain_event_id
                AND de.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND EXISTS (
              SELECT 1
              FROM domain_events de
              WHERE de.id = outbox_messages.domain_event_id
                AND de.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          );

        DROP POLICY IF EXISTS outbox_messages_facility_access ON outbox_messages;
        CREATE POLICY outbox_messages_facility_access ON outbox_messages
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
          );

        DROP POLICY IF EXISTS outbox_messages_citizen_access ON outbox_messages;
        CREATE POLICY outbox_messages_citizen_access ON outbox_messages
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND EXISTS (
              SELECT 1
              FROM domain_events de
              WHERE de.id = outbox_messages.domain_event_id
                AND de.aggregate_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND EXISTS (
              SELECT 1
              FROM domain_events de
              WHERE de.id = outbox_messages.domain_event_id
                AND de.aggregate_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
            )
          );
      SQL
    end
  end
end

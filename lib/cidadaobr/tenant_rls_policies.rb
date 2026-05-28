# frozen_string_literal: true

module Cidadaobr
  module TenantRlsPolicies
    module_function

    def ensure!(connection: ActiveRecord::Base.connection)
      connection.execute core_policies_sql
      ensure_optional_table_policies!(connection)
    end

    def core_policies_sql
      <<~SQL
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
            AND (
              health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              OR EXISTS (
                SELECT 1
                FROM care_teams ct
                WHERE ct.id = domain_events.care_team_id
                  AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              )
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND (
              health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              OR EXISTS (
                SELECT 1
                FROM care_teams ct
                WHERE ct.id = domain_events.care_team_id
                  AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              )
            )
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
            AND (
              health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              OR EXISTS (
                SELECT 1
                FROM domain_events de
                WHERE de.id = outbox_messages.domain_event_id
                  AND (
                    de.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                    OR EXISTS (
                      SELECT 1
                      FROM care_teams ct
                      WHERE ct.id = de.care_team_id
                        AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                    )
                  )
              )
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND (
              health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              OR EXISTS (
                SELECT 1
                FROM domain_events de
                WHERE de.id = outbox_messages.domain_event_id
                  AND (
                    de.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                    OR EXISTS (
                      SELECT 1
                      FROM care_teams ct
                      WHERE ct.id = de.care_team_id
                        AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                    )
                  )
              )
            )
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

    def ensure_optional_table_policies!(connection)
      if connection.table_exists?(:installations)
        connection.execute municipality_scoped_only_table_policies_for(:installations)
      end

      %i[transport_records clinical_records citizens households encounters].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute tenant_table_policies_for(table_name)
      end

      if connection.table_exists?(:micro_areas)
        connection.execute micro_areas_policies
      end

      if connection.table_exists?(:facility_micro_area_coverages)
        connection.execute facility_micro_area_coverage_policies
      end

      if connection.table_exists?(:household_animals)
        connection.execute household_animals_policies
      end

      if connection.table_exists?(:ledi_batches)
        if connection.column_exists?(:ledi_batches, :health_facility_id)
          connection.execute tenant_table_policies_for(:ledi_batches)
        else
          connection.execute municipality_only_table_policies_for(:ledi_batches)
        end
      end

      connection.execute(clinical_record_items_policies) if connection.table_exists?(:clinical_record_items)
      if connection.table_exists?(:household_members) && connection.table_exists?(:households)
        connection.execute(household_members_policies)
      end
    end

    def municipality_scoped_only_table_policies_for(table_name)
      <<~SQL
        ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS #{table_name}_municipal_access ON #{table_name};
        CREATE POLICY #{table_name}_municipal_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
      SQL
    end

    def municipality_only_table_policies_for(table_name)
      <<~SQL
        ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS #{table_name}_municipal_access ON #{table_name};
        CREATE POLICY #{table_name}_municipal_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        CREATE POLICY #{table_name}_team_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
          );

        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
        CREATE POLICY #{table_name}_facility_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
          );
      SQL
    end

    def tenant_table_policies_for(table_name)
      <<~SQL
        ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS #{table_name}_municipal_access ON #{table_name};
        CREATE POLICY #{table_name}_municipal_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        CREATE POLICY #{table_name}_team_access ON #{table_name}
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

        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
        CREATE POLICY #{table_name}_facility_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND (
              health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              OR EXISTS (
                SELECT 1
                FROM care_teams ct
                WHERE ct.id = #{table_name}.care_team_id
                  AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              )
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND (
              health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              OR EXISTS (
                SELECT 1
                FROM care_teams ct
                WHERE ct.id = #{table_name}.care_team_id
                  AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
              )
            )
          );
      SQL
    end

    def clinical_record_items_policies
      <<~SQL
        ALTER TABLE clinical_record_items ENABLE ROW LEVEL SECURITY;
        ALTER TABLE clinical_record_items FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS clinical_record_items_municipal_access ON clinical_record_items;
        CREATE POLICY clinical_record_items_municipal_access ON clinical_record_items
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM clinical_records cr
              WHERE cr.id = clinical_record_items.clinical_record_id
                AND cr.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM clinical_records cr
              WHERE cr.id = clinical_record_items.clinical_record_id
                AND cr.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          );

        DROP POLICY IF EXISTS clinical_record_items_team_access ON clinical_record_items;
        CREATE POLICY clinical_record_items_team_access ON clinical_record_items
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM clinical_records cr
              WHERE cr.id = clinical_record_items.clinical_record_id
                AND cr.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'team'
                AND cr.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM clinical_records cr
              WHERE cr.id = clinical_record_items.clinical_record_id
                AND cr.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'team'
                AND cr.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          );

        DROP POLICY IF EXISTS clinical_record_items_facility_access ON clinical_record_items;
        CREATE POLICY clinical_record_items_facility_access ON clinical_record_items
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM clinical_records cr
              WHERE cr.id = clinical_record_items.clinical_record_id
                AND cr.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND (
                  cr.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = cr.care_team_id
                      AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  )
                )
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM clinical_records cr
              WHERE cr.id = clinical_record_items.clinical_record_id
                AND cr.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND (
                  cr.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = cr.care_team_id
                      AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  )
                )
            )
          );
      SQL
    end

    def micro_areas_policies
      <<~SQL
        ALTER TABLE micro_areas ENABLE ROW LEVEL SECURITY;
        ALTER TABLE micro_areas FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS micro_areas_municipal_access ON micro_areas;
        CREATE POLICY micro_areas_municipal_access ON micro_areas
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS micro_areas_team_access ON micro_areas;
        CREATE POLICY micro_areas_team_access ON micro_areas
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND care_team_id::text = ANY(
              string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
            )
          );

        DROP POLICY IF EXISTS micro_areas_facility_access ON micro_areas;
        CREATE POLICY micro_areas_facility_access ON micro_areas
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.id = micro_areas.care_team_id
                AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
            )
          );
      SQL
    end

    def facility_micro_area_coverage_policies
      <<~SQL
        ALTER TABLE facility_micro_area_coverages ENABLE ROW LEVEL SECURITY;
        ALTER TABLE facility_micro_area_coverages FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS facility_micro_area_coverages_municipal_access ON facility_micro_area_coverages;
        CREATE POLICY facility_micro_area_coverages_municipal_access ON facility_micro_area_coverages
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM health_facilities hf
              WHERE hf.id = facility_micro_area_coverages.health_facility_id
                AND hf.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM health_facilities hf
              WHERE hf.id = facility_micro_area_coverages.health_facility_id
                AND hf.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          );

        DROP POLICY IF EXISTS facility_micro_area_coverages_facility_access ON facility_micro_area_coverages;
        CREATE POLICY facility_micro_area_coverages_facility_access ON facility_micro_area_coverages
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM health_facilities hf
              WHERE hf.id = facility_micro_area_coverages.health_facility_id
                AND hf.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND hf.id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM health_facilities hf
              WHERE hf.id = facility_micro_area_coverages.health_facility_id
                AND hf.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND hf.id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
            )
          );
      SQL
    end

    def household_animals_policies
      <<~SQL
        ALTER TABLE household_animals ENABLE ROW LEVEL SECURITY;
        ALTER TABLE household_animals FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS household_animals_municipal_access ON household_animals;
        CREATE POLICY household_animals_municipal_access ON household_animals
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_animals.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_animals.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          );

        DROP POLICY IF EXISTS household_animals_team_access ON household_animals;
        CREATE POLICY household_animals_team_access ON household_animals
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_animals.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'team'
                AND h.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_animals.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'team'
                AND h.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          );

        DROP POLICY IF EXISTS household_animals_facility_access ON household_animals;
        CREATE POLICY household_animals_facility_access ON household_animals
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_animals.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND (
                  h.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = h.care_team_id
                      AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  )
                )
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_animals.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND (
                  h.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = h.care_team_id
                      AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  )
                )
            )
          );
      SQL
    end

    def household_members_policies
      <<~SQL
        ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;
        ALTER TABLE household_members FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS household_members_municipal_access ON household_members;
        CREATE POLICY household_members_municipal_access ON household_members
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_members.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_members.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          );

        DROP POLICY IF EXISTS household_members_team_access ON household_members;
        CREATE POLICY household_members_team_access ON household_members
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_members.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'team'
                AND h.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_members.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'team'
                AND h.care_team_id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          );

        DROP POLICY IF EXISTS household_members_facility_access ON household_members;
        CREATE POLICY household_members_facility_access ON household_members
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_members.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND (
                  h.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = h.care_team_id
                      AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  )
                )
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM households h
              WHERE h.id = household_members.household_id
                AND h.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'facility'
                AND (
                  h.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = h.care_team_id
                      AND ct.health_facility_id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
                  )
                )
            )
          );
      SQL
    end
  end
end

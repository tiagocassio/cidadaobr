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
      if connection.table_exists?(:health_facilities)
        connection.execute health_facilities_base_policies
        # Citizen-scoped SELECT requires citizens table (applied on re-run after citizens migration).
        connection.execute health_facilities_citizen_access_policy if connection.table_exists?(:citizens)
      end

      if connection.table_exists?(:installations)
        connection.execute municipality_scoped_only_table_policies_for(:installations)
      end

      %i[transport_records clinical_records citizens households encounters].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute tenant_table_policies_for(table_name)
      end

      if connection.table_exists?(:citizens)
        connection.execute citizens_citizen_self_read_policy
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

      %i[consultation_rooms room_capacity_slots].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute health_facility_scoped_table_policies_for(table_name)
      end

      if connection.table_exists?(:appointments)
        connection.execute tenant_table_policies_for(:appointments)
        connection.execute tenant_table_citizen_access_policy_for(:appointments)
        include_panic_alerts = connection.table_exists?(:panic_alerts)
        include_teleconsultation_sessions = connection.table_exists?(:teleconsultation_sessions)
        include_continuous_medications = connection.table_exists?(:citizen_continuous_medications)
        citizen_event_options = {
          include_appointments: true,
          include_panic_alerts: include_panic_alerts,
          include_teleconsultation_sessions: include_teleconsultation_sessions,
          include_continuous_medications: include_continuous_medications
        }
        connection.execute citizen_domain_event_access_policies_sql(**citizen_event_options)
        connection.execute citizen_outbox_message_access_policies_sql(**citizen_event_options)
        connection.execute citizen_scheduling_catalog_policies_sql(connection)
      end

      if connection.table_exists?(:appointment_room_slots) && connection.table_exists?(:appointments)
        connection.execute appointment_room_slots_citizen_access_policy
      end

      %i[appointment_waitlist_entries professional_availability_blocks].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute health_facility_scoped_table_policies_for(table_name)
      end

      if connection.table_exists?(:appointment_room_slots)
        connection.execute health_facility_scoped_table_policies_for(:appointment_room_slots)
      end
      %i[appointment_service_types].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute municipality_only_table_policies_for(table_name)
      end

      if connection.table_exists?(:citizen_accounts)
        connection.execute citizen_table_policies_for(:citizen_accounts)
      end

      if connection.table_exists?(:citizen_immunization_records)
        connection.execute municipality_only_table_policies_for(:citizen_immunization_records)
        connection.execute tenant_table_citizen_access_policy_for(:citizen_immunization_records)
      end

      if connection.table_exists?(:panic_alerts)
        connection.execute panic_alerts_table_policies
        connection.execute tenant_table_citizen_access_policy_for(:panic_alerts)
      end

      if connection.table_exists?(:shared_care_cases)
        connection.execute shared_care_case_policies
      end

      if connection.table_exists?(:shared_care_evolutions)
        connection.execute shared_care_evolution_policies
      end

      if connection.table_exists?(:teleconsultation_sessions)
        connection.execute citizen_scoped_table_policies_for(:teleconsultation_sessions)
        connection.execute tenant_table_citizen_access_policy_for(:teleconsultation_sessions)
      end

      if connection.table_exists?(:citizen_continuous_medications)
        connection.execute citizen_scoped_table_policies_for(:citizen_continuous_medications)
        connection.execute tenant_table_citizen_access_policy_for(:citizen_continuous_medications)
      end

      if connection.table_exists?(:citizen_indicator_gaps)
        connection.execute citizen_indicator_gap_table_policies_for(:citizen_indicator_gaps)
        connection.execute tenant_table_citizen_access_policy_for(:citizen_indicator_gaps)
      end

      if connection.table_exists?(:team_indicator_results)
        connection.execute team_indicator_result_table_policies_for(:team_indicator_results)
      end

      %i[
        immunobiological_products
        supply_items
        supply_item_components
        home_visit_campaign_supply_plans
      ].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute municipality_only_table_policies_for(table_name)
      end

      %i[
        immunobiological_lots
        stock_balances
        stock_movements
        vaccination_campaigns
        supply_provisioning
        campaign_targets
        home_visit_campaigns
        home_visit_campaign_provisioning
        visit_routes
        visit_route_provisioning
        team_supply_dispatches
      ].each do |table_name|
        next unless connection.table_exists?(table_name)

        connection.execute health_facility_scoped_table_policies_for(table_name)
      end

      if connection.table_exists?(:visit_route_stops)
        connection.execute municipality_only_table_policies_for(:visit_route_stops)
      end
    end

    def citizens_citizen_self_read_policy
      <<~SQL
        DROP POLICY IF EXISTS citizens_citizen_access ON citizens;
        CREATE POLICY citizens_citizen_access ON citizens
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          );
      SQL
    end

    def health_facility_scoped_table_policies_for(table_name)
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
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.health_facility_id = #{table_name}.health_facility_id
                AND ct.id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.health_facility_id = #{table_name}.health_facility_id
                AND ct.id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          );

        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
        CREATE POLICY #{table_name}_facility_access ON #{table_name}
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
      SQL
    end

    def tenant_table_citizen_access_policy_for(table_name)
      <<~SQL
        DROP POLICY IF EXISTS #{table_name}_citizen_access ON #{table_name};
        CREATE POLICY #{table_name}_citizen_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          );
      SQL
    end

    def citizen_domain_event_access_policies_sql(include_appointments: false, include_panic_alerts: false, include_teleconsultation_sessions: false, include_continuous_medications: false)
      aggregate_condition = citizen_domain_event_aggregate_condition(
        include_appointments,
        include_panic_alerts: include_panic_alerts,
        include_teleconsultation_sessions: include_teleconsultation_sessions,
        include_continuous_medications: include_continuous_medications
      )

      <<~SQL
        DROP POLICY IF EXISTS domain_events_citizen_access ON domain_events;
        CREATE POLICY domain_events_citizen_access ON domain_events
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND #{aggregate_condition}
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND #{aggregate_condition}
          );
      SQL
    end

    def citizen_outbox_message_access_policies_sql(include_appointments: false, include_panic_alerts: false, include_teleconsultation_sessions: false, include_continuous_medications: false)
      aggregate_condition = citizen_domain_event_aggregate_condition(
        include_appointments,
        include_panic_alerts: include_panic_alerts,
        include_teleconsultation_sessions: include_teleconsultation_sessions,
        include_continuous_medications: include_continuous_medications,
        table_alias: "de"
      )

      <<~SQL
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
                AND #{aggregate_condition}
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND EXISTS (
              SELECT 1
              FROM domain_events de
              WHERE de.id = outbox_messages.domain_event_id
                AND #{aggregate_condition}
            )
          );
      SQL
    end

    def citizen_domain_event_aggregate_condition(include_appointments, include_panic_alerts: false, include_teleconsultation_sessions: false, include_continuous_medications: false, table_alias: "domain_events")
      citizen_id_expr = "NULLIF(current_setting('app.current_citizen_id', true), '')::uuid"
      aggregate_ref = "#{table_alias}.aggregate_id"

      if include_appointments
        clauses = [
          "#{aggregate_ref} = #{citizen_id_expr}",
          <<~SQL.squish,
            (
              #{table_alias}.aggregate_type = 'Appointment'
              AND EXISTS (
                SELECT 1
                FROM appointments a
                WHERE a.id = #{aggregate_ref}
                  AND a.citizen_id = #{citizen_id_expr}
              )
            )
          SQL
        ]
        if include_panic_alerts
          clauses << <<~SQL.squish
            (
              #{table_alias}.aggregate_type = 'PanicAlert'
              AND EXISTS (
                SELECT 1
                FROM panic_alerts pa
                WHERE pa.id = #{aggregate_ref}
                  AND pa.citizen_id = #{citizen_id_expr}
              )
            )
          SQL
        end
        if include_teleconsultation_sessions
          clauses << <<~SQL.squish
            (
              #{table_alias}.aggregate_type = 'TeleconsultationSession'
              AND EXISTS (
                SELECT 1
                FROM teleconsultation_sessions ts
                WHERE ts.id = #{aggregate_ref}
                  AND ts.citizen_id = #{citizen_id_expr}
              )
            )
          SQL
        end
        if include_continuous_medications
          clauses << <<~SQL.squish
            (
              #{table_alias}.aggregate_type = 'CitizenContinuousMedication'
              AND EXISTS (
                SELECT 1
                FROM citizen_continuous_medications cm
                WHERE cm.id = #{aggregate_ref}
                  AND cm.citizen_id = #{citizen_id_expr}
              )
            )
          SQL
        end
        "(#{clauses.join(' OR ')})"
      else
        "#{aggregate_ref} = #{citizen_id_expr}"
      end
    end

    def citizen_scheduling_catalog_policies_sql(connection)
      sql = +""
      if connection.table_exists?(:consultation_rooms)
        sql << citizen_facility_scoped_read_policy_for(:consultation_rooms)
      end
      if connection.table_exists?(:room_capacity_slots)
        sql << citizen_facility_scoped_read_policy_for(:room_capacity_slots)
      end
      sql << citizen_municipality_read_policy_for(:appointment_service_types) if connection.table_exists?(:appointment_service_types)
      sql << room_capacity_slots_citizen_booking_policy if connection.table_exists?(:room_capacity_slots)
      sql
    end

    def citizen_facility_scoped_read_policy_for(table_name)
      citizen_id_expr = "NULLIF(current_setting('app.current_citizen_id', true), '')::uuid"

      <<~SQL
        DROP POLICY IF EXISTS #{table_name}_citizen_read ON #{table_name};
        CREATE POLICY #{table_name}_citizen_read ON #{table_name}
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND health_facility_id = (
              SELECT c.health_facility_id
              FROM citizens c
              WHERE c.id = #{citizen_id_expr}
            )
          );
      SQL
    end

    def citizen_municipality_read_policy_for(table_name)
      <<~SQL
        DROP POLICY IF EXISTS #{table_name}_citizen_read ON #{table_name};
        CREATE POLICY #{table_name}_citizen_read ON #{table_name}
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
          );
      SQL
    end

    def room_capacity_slots_citizen_booking_policy
      <<~SQL
        DROP POLICY IF EXISTS room_capacity_slots_citizen_booking ON room_capacity_slots;
        CREATE POLICY room_capacity_slots_citizen_booking ON room_capacity_slots
          FOR UPDATE
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND EXISTS (
              SELECT 1
              FROM appointment_room_slots ars
              INNER JOIN appointments a ON a.id = ars.appointment_id
              WHERE ars.room_capacity_slot_id = room_capacity_slots.id
                AND ars.status = 'reserved'
                AND a.citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
          );
      SQL
    end

    def appointment_room_slots_citizen_access_policy
      <<~SQL
        DROP POLICY IF EXISTS appointment_room_slots_citizen_access ON appointment_room_slots;
        CREATE POLICY appointment_room_slots_citizen_access ON appointment_room_slots
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND EXISTS (
              SELECT 1
              FROM appointments a
              WHERE a.id = appointment_room_slots.appointment_id
                AND a.citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
            )
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND EXISTS (
              SELECT 1
              FROM appointments a
              WHERE a.id = appointment_room_slots.appointment_id
                AND a.citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
            )
          );
      SQL
    end

    def citizen_table_policies_for(table_name)
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

        DROP POLICY IF EXISTS #{table_name}_citizen_access ON #{table_name};
        CREATE POLICY #{table_name}_citizen_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND citizen_id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
      SQL
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

    def citizen_indicator_gap_table_policies_for(table_name)
      team_ids_array = "string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')"
      facility_id = "NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid"
      municipality_id = "NULLIF(current_setting('app.current_municipality_id', true), '')::uuid"

      citizen_facility_match = <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM citizens c
          WHERE c.id = #{table_name}.citizen_id
            AND c.municipality_id = #{table_name}.municipality_id
            AND (
              c.health_facility_id = #{facility_id}
              OR EXISTS (
                SELECT 1
                FROM care_teams ct
                WHERE ct.id = c.care_team_id
                  AND ct.health_facility_id = #{facility_id}
              )
            )
        )
      SQL

      gap_team_facility_match = <<~SQL.squish
        (
          #{table_name}.care_team_id IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM care_teams ct
            WHERE ct.id = #{table_name}.care_team_id
              AND ct.health_facility_id = #{facility_id}
          )
        )
      SQL

      team_scope_match = <<~SQL.squish
        (
          (#{table_name}.care_team_id IS NOT NULL AND #{table_name}.care_team_id::text = ANY(#{team_ids_array}))
          OR EXISTS (
            SELECT 1
            FROM citizens c
            WHERE c.id = #{table_name}.citizen_id
              AND c.care_team_id::text = ANY(#{team_ids_array})
          )
        )
      SQL

      <<~SQL
        ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS #{table_name}_municipal_access ON #{table_name};
        CREATE POLICY #{table_name}_municipal_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        CREATE POLICY #{table_name}_team_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND #{team_scope_match}
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND #{team_scope_match}
          );

        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
        CREATE POLICY #{table_name}_facility_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND (#{citizen_facility_match} OR #{gap_team_facility_match})
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND (#{citizen_facility_match} OR #{gap_team_facility_match})
          );
      SQL
    end

    def team_indicator_result_table_policies_for(table_name)
      team_ids_array = "string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')"
      facility_id = "NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid"
      municipality_id = "NULLIF(current_setting('app.current_municipality_id', true), '')::uuid"

      <<~SQL
        ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS #{table_name}_municipal_access ON #{table_name};
        CREATE POLICY #{table_name}_municipal_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        CREATE POLICY #{table_name}_team_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND care_team_id::text = ANY(#{team_ids_array})
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND care_team_id::text = ANY(#{team_ids_array})
          );

        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
        CREATE POLICY #{table_name}_facility_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.id = #{table_name}.care_team_id
                AND ct.health_facility_id = #{facility_id}
            )
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.id = #{table_name}.care_team_id
                AND ct.health_facility_id = #{facility_id}
            )
          );
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

    def panic_alerts_table_policies
      citizen_scoped_table_policies_for(:panic_alerts)
    end

    def citizen_scoped_table_policies_for(table_name)
      team_ids_array = "string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')"
      facility_id = "NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid"
      municipality_id = "NULLIF(current_setting('app.current_municipality_id', true), '')::uuid"

      citizen_facility_match = <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM citizens c
          WHERE c.id = #{table_name}.citizen_id
            AND c.municipality_id = #{table_name}.municipality_id
            AND (
              c.health_facility_id = #{facility_id}
              OR EXISTS (
                SELECT 1
                FROM care_teams ct
                WHERE ct.id = c.care_team_id
                  AND ct.health_facility_id = #{facility_id}
              )
            )
        )
      SQL

      team_scope_match = <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM citizens c
          WHERE c.id = #{table_name}.citizen_id
            AND (
              c.care_team_id::text = ANY(#{team_ids_array})
              OR (
                c.health_facility_id IS NOT NULL
                AND EXISTS (
                  SELECT 1
                  FROM care_teams ct
                  WHERE ct.id::text = ANY(#{team_ids_array})
                    AND ct.health_facility_id = c.health_facility_id
                )
              )
            )
        )
      SQL

      <<~SQL
        ALTER TABLE #{table_name} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table_name} FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS #{table_name}_municipal_access ON #{table_name};
        CREATE POLICY #{table_name}_municipal_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS #{table_name}_team_access ON #{table_name};
        CREATE POLICY #{table_name}_team_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND #{team_scope_match}
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND #{team_scope_match}
          );

        DROP POLICY IF EXISTS #{table_name}_facility_access ON #{table_name};
        CREATE POLICY #{table_name}_facility_access ON #{table_name}
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND #{citizen_facility_match}
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND #{citizen_facility_match}
          );
      SQL
    end

    def shared_care_case_policies
      team_ids_array = "string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')"
      facility_id = "NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid"
      municipality_id = "NULLIF(current_setting('app.current_municipality_id', true), '')::uuid"

      shared_care_team_match = <<~SQL.squish
        (
          (shared_care_cases.origin_care_team_id IS NOT NULL AND shared_care_cases.origin_care_team_id::text = ANY(#{team_ids_array}))
          OR EXISTS (
            SELECT 1
            FROM citizens c
            WHERE c.id = shared_care_cases.citizen_id
              AND (
                c.care_team_id::text = ANY(#{team_ids_array})
                OR (
                  c.health_facility_id IS NOT NULL
                  AND EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id::text = ANY(#{team_ids_array})
                      AND ct.health_facility_id = c.health_facility_id
                  )
                )
              )
          )
        )
      SQL

      shared_care_facility_match = <<~SQL.squish
        (
          (
            shared_care_cases.origin_care_team_id IS NOT NULL
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.id = shared_care_cases.origin_care_team_id
                AND ct.health_facility_id = #{facility_id}
            )
          )
          OR (
            shared_care_cases.origin_care_team_id IS NULL
            AND EXISTS (
              SELECT 1
              FROM citizens c
              WHERE c.id = shared_care_cases.citizen_id
                AND (
                  c.health_facility_id = #{facility_id}
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = c.care_team_id
                      AND ct.health_facility_id = #{facility_id}
                  )
                )
            )
          )
        )
      SQL

      <<~SQL
        ALTER TABLE shared_care_cases ENABLE ROW LEVEL SECURITY;
        ALTER TABLE shared_care_cases FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS shared_care_cases_municipal_access ON shared_care_cases;
        CREATE POLICY shared_care_cases_municipal_access ON shared_care_cases
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS shared_care_cases_team_access ON shared_care_cases;
        CREATE POLICY shared_care_cases_team_access ON shared_care_cases
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND #{shared_care_team_match}
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'team'
            AND #{shared_care_team_match}
          );

        DROP POLICY IF EXISTS shared_care_cases_facility_access ON shared_care_cases;
        CREATE POLICY shared_care_cases_facility_access ON shared_care_cases
          FOR ALL
          USING (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND #{shared_care_facility_match}
          )
          WITH CHECK (
            municipality_id = #{municipality_id}
            AND current_setting('app.current_scope', true) = 'facility'
            AND #{shared_care_facility_match}
          );
      SQL
    end

    def shared_care_evolution_policies
      team_ids_array = "string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')"
      facility_id = "NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid"
      municipality_id = "NULLIF(current_setting('app.current_municipality_id', true), '')::uuid"

      scc_team_match = <<~SQL.squish
        (
          (scc.origin_care_team_id IS NOT NULL AND scc.origin_care_team_id::text = ANY(#{team_ids_array}))
          OR EXISTS (
            SELECT 1
            FROM citizens c
            WHERE c.id = scc.citizen_id
              AND (
                c.care_team_id::text = ANY(#{team_ids_array})
                OR (
                  c.health_facility_id IS NOT NULL
                  AND EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id::text = ANY(#{team_ids_array})
                      AND ct.health_facility_id = c.health_facility_id
                  )
                )
              )
          )
        )
      SQL

      scc_facility_match = <<~SQL.squish
        (
          (
            scc.origin_care_team_id IS NOT NULL
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.id = scc.origin_care_team_id
                AND ct.health_facility_id = #{facility_id}
            )
          )
          OR (
            scc.origin_care_team_id IS NULL
            AND EXISTS (
              SELECT 1
              FROM citizens c
              WHERE c.id = scc.citizen_id
                AND (
                  c.health_facility_id = #{facility_id}
                  OR EXISTS (
                    SELECT 1
                    FROM care_teams ct
                    WHERE ct.id = c.care_team_id
                      AND ct.health_facility_id = #{facility_id}
                  )
                )
            )
          )
        )
      SQL

      <<~SQL
        ALTER TABLE shared_care_evolutions ENABLE ROW LEVEL SECURITY;
        ALTER TABLE shared_care_evolutions FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS shared_care_evolutions_municipal_access ON shared_care_evolutions;
        CREATE POLICY shared_care_evolutions_municipal_access ON shared_care_evolutions
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM shared_care_cases scc
              WHERE scc.id = shared_care_evolutions.shared_care_case_id
                AND scc.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM shared_care_cases scc
              WHERE scc.id = shared_care_evolutions.shared_care_case_id
                AND scc.municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
                AND current_setting('app.current_scope', true) = 'municipality'
            )
          );

        DROP POLICY IF EXISTS shared_care_evolutions_team_access ON shared_care_evolutions;
        CREATE POLICY shared_care_evolutions_team_access ON shared_care_evolutions
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM shared_care_cases scc
              WHERE scc.id = shared_care_evolutions.shared_care_case_id
                AND scc.municipality_id = #{municipality_id}
                AND current_setting('app.current_scope', true) = 'team'
                AND #{scc_team_match}
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM shared_care_cases scc
              WHERE scc.id = shared_care_evolutions.shared_care_case_id
                AND scc.municipality_id = #{municipality_id}
                AND current_setting('app.current_scope', true) = 'team'
                AND #{scc_team_match}
            )
          );

        DROP POLICY IF EXISTS shared_care_evolutions_facility_access ON shared_care_evolutions;
        CREATE POLICY shared_care_evolutions_facility_access ON shared_care_evolutions
          FOR ALL
          USING (
            EXISTS (
              SELECT 1
              FROM shared_care_cases scc
              WHERE scc.id = shared_care_evolutions.shared_care_case_id
                AND scc.municipality_id = #{municipality_id}
                AND current_setting('app.current_scope', true) = 'facility'
                AND #{scc_facility_match}
            )
          )
          WITH CHECK (
            EXISTS (
              SELECT 1
              FROM shared_care_cases scc
              WHERE scc.id = shared_care_evolutions.shared_care_case_id
                AND scc.municipality_id = #{municipality_id}
                AND current_setting('app.current_scope', true) = 'facility'
                AND #{scc_facility_match}
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

    def health_facilities_base_policies
      <<~SQL
        ALTER TABLE health_facilities ENABLE ROW LEVEL SECURITY;
        ALTER TABLE health_facilities FORCE ROW LEVEL SECURITY;

        DROP POLICY IF EXISTS health_facilities_municipal_access ON health_facilities;
        CREATE POLICY health_facilities_municipal_access ON health_facilities
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'municipality'
          );

        DROP POLICY IF EXISTS health_facilities_team_access ON health_facilities;
        CREATE POLICY health_facilities_team_access ON health_facilities
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'team'
            AND EXISTS (
              SELECT 1
              FROM care_teams ct
              WHERE ct.health_facility_id = health_facilities.id
                AND ct.id::text = ANY(
                  string_to_array(NULLIF(current_setting('app.current_team_ids', true), ''), ',')
                )
            )
          );

        DROP POLICY IF EXISTS health_facilities_facility_access ON health_facilities;
        CREATE POLICY health_facilities_facility_access ON health_facilities
          FOR ALL
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
          )
          WITH CHECK (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'facility'
            AND id = NULLIF(current_setting('app.current_health_facility_id', true), '')::uuid
          );
      SQL
    end

    def health_facilities_citizen_access_policy
      <<~SQL
        DROP POLICY IF EXISTS health_facilities_citizen_access ON health_facilities;
        CREATE POLICY health_facilities_citizen_access ON health_facilities
          FOR SELECT
          USING (
            municipality_id = NULLIF(current_setting('app.current_municipality_id', true), '')::uuid
            AND current_setting('app.current_scope', true) = 'citizen'
            AND id = (
              SELECT c.health_facility_id
              FROM citizens c
              WHERE c.id = NULLIF(current_setting('app.current_citizen_id', true), '')::uuid
            )
          );
      SQL
    end

    def health_facilities_policies
      health_facilities_base_policies + health_facilities_citizen_access_policy
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

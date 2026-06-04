# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module ClinicalEvidence
        ATTENDANCE_RECORD_TYPES = %w[FAI FAO FP FAC].freeze
        CONTACT_RECORD_TYPES = %w[FAI FAO FP FVD FAC FV MCA].freeze

        module_function

        def matches?(clause, context)
          case clause["type"]
          when "registration_complete" then registration_complete?(context)
          when "registration_updated_mici" then registration_updated_mici?(context, clause)
          when "registration_within_team_limit" then registration_within_team_limit?(context, clause)
          when "mici_micdt_complete" then mici_micdt_complete?(context)
          when "fci_updated_within" then fci_updated_within?(context, clause)
          when "clinical_predicate" then clinical_predicate?(context, clause)
          when "appointment_in_quadrimester" then appointment_in_quadrimester?(context, clause)
          when "encounter_in_window" then encounter_in_window?(context, clause)
          when "emulti_encounter_count" then emulti_encounter_count?(context, clause)
          when "contact_and_attendance" then contact_and_attendance?(context, clause)
          when "satisfaction_survey" then satisfaction_survey?(context, clause)
          when "consult_count_gte" then consult_count_gte?(context, clause)
          when "anthropometry_count_gte" then anthropometry_count_gte?(context, clause)
          when "visit_count_gte" then visit_count_gte?(context, clause)
          when "acs_two_visit_schedule" then acs_two_visit_schedule?(context, clause)
          when "blood_pressure_count_gte" then blood_pressure_count_gte?(context, clause)
          when "first_consult_by_age" then first_consult_by_age?(context, clause)
          when "first_prenatal_consult" then first_prenatal_consult?(context, clause)
          when "vaccination_present" then vaccination_present?(context, clause)
          when "vaccination_calendar" then vaccination_calendar?(context, clause)
          when "vaccination_immunobiological" then vaccination_immunobiological?(context, clause)
          when "gestational_vaccination_immunobiological" then gestational_vaccination_immunobiological?(context, clause)
          when "gestational_clinical_predicate" then gestational_clinical_predicate?(context, clause)
          when "gestational_evidence_count_gte" then gestational_evidence_count_gte?(context, clause)
          when "puerperium_consult" then puerperium_consult?(context, clause)
          when "puerperium_visit" then puerperium_visit?(context, clause)
          when "fci_flag_present" then fci_flag_present?(context, clause)
          when "microarea_linked" then microarea_linked?(context)
          else
            false
          end
        end

        def registration_complete?(context)
          RegistrationValidators.mici_complete?(context.citizen)
        end

        def mici_micdt_complete?(context)
          RegistrationValidators.mici_complete?(context.citizen) &&
            RegistrationValidators.micdt_complete?(context.citizen)
        end

        def registration_updated_mici?(context, clause)
          fci_updated_within?(context, clause)
        end

        def fci_updated_within?(context, clause)
          return false unless RegistrationValidators.mici_complete?(context.citizen)

          updated_at = RegistrationValidators.fci_updated_at(context.citizen)
          return false if updated_at.nil?

          within_months = clause.fetch("within_months", 24).to_i
          window_start = context.reference_date - within_months.months
          updated_at.to_date >= window_start
        end

        def registration_within_team_limit?(context, clause)
          return false unless RegistrationValidators.mici_complete?(context.citizen)

          limit = clause.fetch("team_limit", 3_500).to_i
          team_id = context.citizen.care_team_id
          return true if team_id.blank?

          RegistrationValidators.team_citizen_count(context.citizen, context.cache) <= limit
        end

        def contact_and_attendance?(context, clause)
          within_months = clause.fetch("within_months", 12).to_i
          min_contacts = clause.fetch("minimum_contacts", 2).to_i
          min_attendances = clause.fetch("minimum_attendances", 1).to_i
          contact_types = Array(clause.fetch("record_types", CONTACT_RECORD_TYPES))
          attendance_types = Array(clause.fetch("attendance_record_types", ATTENDANCE_RECORD_TYPES))

          contacts = count_records_in_window(context, contact_types, within_months)
          attendances = count_records_in_window(context, attendance_types, within_months)

          contacts >= min_contacts && attendances >= min_attendances
        end

        def satisfaction_survey?(context, clause)
          team = context.care_team || context.citizen.care_team
          if team && !clause["external_only"]
            score = TeamSatisfactionSurveyScore.best_score_for_team(
              care_team: team,
              quadrimester: context.quadrimester,
              reference_date: context.reference_date
            )
            return score.to_f >= clause.fetch("min_score", 7.0).to_f if score
          end

          return false if clause["external_only"]

          return false unless clause.fetch("fallback_encounter", true)

          encounter_in_window?(context, clause)
        end

        def consult_count_gte?(context, clause)
          count_records_in_window(
            context,
            Array(clause.fetch("record_types", %w[FAI])),
            clause.fetch("within_months", 6).to_i
          ) >= clause.fetch("minimum_count", 1).to_i
        end

        def visit_count_gte?(context, clause)
          within_months = clause.fetch("within_months", 12).to_i
          minimum = clause.fetch("minimum_count", 2).to_i
          interval = clause.fetch("minimum_interval_days", 0).to_i
          record_types = Array(clause.fetch("record_types", %w[FVD]))
          dates = record_dates_in_window(context, record_types, within_months)
          return dates.size >= minimum if interval <= 0

          dates.sort!
          dates.each_cons(minimum) do |group|
            return true if (group.last - group.first).to_i >= interval
          end
          false
        end

        def acs_two_visit_schedule?(context, clause)
          birth = context.citizen.birth_date
          return false unless birth

          record_types = Array(clause.fetch("record_types", %w[FVD]))
          first_max_days = clause.fetch("first_visit_max_days", 30).to_i
          second_within_months = clause.fetch("second_visit_within_months", 6).to_i
          second_deadline = birth + second_within_months.months

          dates = record_dates_between(context, record_types, start_date: birth, end_date: second_deadline).sort
          return false if dates.size < 2

          first_deadline = birth + first_max_days.days
          first_visit = dates.find { |date| date <= first_deadline }
          return false unless first_visit

          dates.any? { |date| date > first_visit }
        end

        def anthropometry_count_gte?(context, clause)
          within_months = clause.fetch("within_months", 12).to_i
          minimum = clause.fetch("minimum_count", 1).to_i
          record_types = Array(clause.fetch("record_types", %w[FAI FVD FAC]))
          count = 0

          records_in_window(context, record_types, within_months).each do |record|
            payloads_for_record(record, context.citizen).each do |payload|
              count += 1 if anthropometry_present?(payload, record.record_type)
            end
          end

          count >= minimum
        end

        def blood_pressure_count_gte?(context, clause)
          within_months = clause.fetch("within_months", 6).to_i
          minimum = clause.fetch("minimum_count", 1).to_i
          record_types = Array(clause.fetch("record_types", %w[FAI FP FVD]))
          count = 0

          records_in_window(context, record_types, within_months).each do |record|
            payloads_for_record(record, context.citizen).each do |payload|
              count += 1 if blood_pressure_present?(payload, record.record_type)
            end
          end

          count >= minimum
        end

        def first_consult_by_age?(context, clause)
          max_days = clause.fetch("max_days", 30).to_i
          birth = context.citizen.birth_date
          return false unless birth

          record_types = Array(clause.fetch("record_types", %w[FAI]))
          record_dates_between(
            context,
            record_types,
            start_date: birth,
            end_date: birth + max_days.days
          ).any?
        end

        def first_prenatal_consult?(context, clause)
          first_prenatal_consult_date(context, clause).present?
        end

        def first_prenatal_consult_date(context, clause)
          lookback_months = clause.fetch("lookback_months", clause.fetch("within_months", 15)).to_i
          record_types = Array(clause.fetch("record_types", %w[FAI]))
          predicate = clause.fetch("predicate", LediPayloadPaths::PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE)
          dum = GestationalAnchor.latest_dum(
            context.citizen,
            context,
            lookback_months: lookback_months,
            active_only: GestationalAnchor::RETROSPECTIVE_ACTIVE_ONLY_DEFAULT
          )
          return nil unless dum

          delivery = GestationalAnchor.delivery_for_dum(
            context.citizen,
            context,
            dum,
            lookback_months: lookback_months
          )
          window_start = context.reference_date - lookback_months.months
          consult_dates = clinical_records_for(context.citizen, record_types, since: window_start, context: context).filter_map do |record|
            next unless record_matches_predicate?(record, context, predicate)

            encounter_date = encounter_date_for(record, context)
            next unless encounter_date && encounter_date >= dum
            next if delivery && encounter_date >= delivery

            encounter_date
          end
          return nil if consult_dates.empty?

          first_consult = consult_dates.min
          return first_consult unless clause.key?("max_weeks")

          max_weeks = clause.fetch("max_weeks").to_i
          week = GestationalAnchor.gestational_week_at(dum, first_consult)
          week && week <= max_weeks ? first_consult : nil
        end

        def gestational_evidence_count_gte?(context, clause)
          min_weeks = clause.fetch("min_gestational_weeks", 0).to_i
          max_weeks = clause.fetch("max_gestational_weeks", 42).to_i
          minimum = clause.fetch("minimum_count", 1).to_i
          lookback_months = clause.fetch("lookback_months", 15).to_i
          active_only = clause.fetch("active_only", GestationalAnchor::RETROSPECTIVE_ACTIVE_ONLY_DEFAULT)
          record_types = Array(clause.fetch("record_types"))
          measure = clause["measure"].to_s
          return false unless GestationalAnchor::GESTATIONAL_EVIDENCE_MEASURES.include?(measure)

          predicate = clause["predicate"]
          after_first_prenatal = clause.fetch("after_first_prenatal", false)

          first_prenatal_at = nil
          if after_first_prenatal
            first_prenatal_clause = {
              "lookback_months" => lookback_months,
              "record_types" => Array(clause.fetch("first_prenatal_record_types", %w[FAI])),
              "predicate" => clause.fetch(
                "first_prenatal_predicate",
                LediPayloadPaths::PRENATAL_INDIVIDUAL_ATTENDANCE_PREDICATE
              )
            }
            first_prenatal_clause["max_weeks"] = clause["first_prenatal_max_weeks"] if clause.key?("first_prenatal_max_weeks")
            first_prenatal_at = first_prenatal_consult_date(context, first_prenatal_clause)
            return false unless first_prenatal_at
          end

          records = GestationalAnchor.records_in_gestational_window(
            context.citizen,
            context,
            record_types: record_types,
            min_weeks: min_weeks,
            max_weeks: max_weeks,
            lookback_months: lookback_months,
            active_only: active_only,
            exclude_after_delivery: true
          )

          count = records.count do |record|
            next false unless gestational_measure_present?(record, context, measure, predicate)

            if after_first_prenatal
              encounter_date = encounter_date_for(record, context)
              next false unless encounter_date && encounter_date >= first_prenatal_at
            end

            true
          end

          count >= minimum
        end

        def vaccination_present?(context, clause)
          vaccination_immunobiological?(context, clause.merge("immunobiological" => nil))
        end

        def vaccination_calendar?(context, clause)
          birth = context.citizen.birth_date
          return false unless birth

          within_months = clause.fetch("within_months", 24).to_i
          scope_max_age_days = (within_months * 30.4375).floor
          age_days = (context.reference_date - birth).to_i
          return false if age_days.negative? || age_days > scope_max_age_days

          result = Indicators::PniScheduleEvaluator.evaluate(
            citizen: context.citizen,
            reference_date: context.reference_date,
            age_group: clause.fetch("age_group", "child"),
            scope_max_age_days: scope_max_age_days,
            context: context
          )
          return false unless result.evaluable

          result.compliant
        end

        def vaccination_immunobiological?(context, clause)
          within_months = clause.fetch("within_months", 24).to_i
          target = clause["immunobiological"]&.to_s&.downcase
          record_types = Array(clause.fetch("record_types", %w[FV]))

          records_in_window(context, record_types, within_months).any? do |record|
            payloads_for_record(record, context.citizen).any? do |payload|
              vaccination_match?(payload, target)
            end
          end
        end

        def gestational_vaccination_immunobiological?(context, clause)
          min_weeks = clause.fetch("min_gestational_weeks", 20).to_i
          max_weeks = clause.fetch("max_gestational_weeks", 42).to_i
          lookback_months = clause.fetch("lookback_months", 15).to_i
          active_only = clause.fetch("active_only", GestationalAnchor::RETROSPECTIVE_ACTIVE_ONLY_DEFAULT)
          target = clause["immunobiological"]&.to_s&.downcase
          record_types = Array(clause.fetch("record_types", %w[FV]))

          GestationalAnchor.records_in_gestational_window(
            context.citizen,
            context,
            record_types: record_types,
            min_weeks: min_weeks,
            max_weeks: max_weeks,
            lookback_months: lookback_months,
            active_only: active_only,
            exclude_after_delivery: true
          ).any? do |record|
            payloads_for_record(record, context.citizen).any? do |payload|
              vaccination_match?(
                payload,
                target,
                immunobiological_code: clause["immunobiological_code"]
              )
            end
          end
        end

        def gestational_clinical_predicate?(context, clause)
          min_weeks = clause.fetch("min_gestational_weeks", 0).to_i
          max_weeks = clause.fetch("max_gestational_weeks", 13).to_i
          lookback_months = clause.fetch("lookback_months", 15).to_i
          active_only = clause.fetch("active_only", GestationalAnchor::RETROSPECTIVE_ACTIVE_ONLY_DEFAULT)
          record_types = Array(clause["record_types"]).map(&:to_s)
          predicate = clause.fetch("predicate", {})

          GestationalAnchor.records_in_gestational_window(
            context.citizen,
            context,
            record_types: record_types,
            min_weeks: min_weeks,
            max_weeks: max_weeks,
            lookback_months: lookback_months,
            active_only: active_only,
            exclude_after_delivery: true
          ).any? do |record|
            record_matches_predicate?(record, context, predicate)
          end
        end

        # C3-I: postpartum consult only — excludes parto FAI on delivery day (after_delivery: true).
        def puerperium_consult?(context, clause)
          days = clause.fetch("days_after_delivery", GestationalAnchor::PUERPERIUM_DAYS).to_i
          record_types = Array(clause.fetch("record_types", %w[FAI]))
          predicate = clause.fetch(
            "predicate",
            { "type" => "present", "field_path" => "individual_attendances" }
          )

          GestationalAnchor.records_in_puerperium_window(
            context.citizen,
            context,
            record_types: record_types,
            days_after_delivery: days,
            after_delivery: true
          ).any? do |record|
            record_matches_predicate?(record, context, predicate)
          end
        end

        def puerperium_visit?(context, clause)
          days = clause.fetch("days_after_delivery", GestationalAnchor::PUERPERIUM_DAYS).to_i
          minimum = clause.fetch("minimum_count", 1).to_i
          record_types = Array(clause.fetch("record_types", %w[FVD]))
          predicate = clause.fetch(
            "predicate",
            { "type" => "present", "field_path" => "visit_reasons" }
          )

          count = GestationalAnchor.records_in_puerperium_window(
            context.citizen,
            context,
            record_types: record_types,
            days_after_delivery: days,
            after_delivery: true
          ).count do |record|
            record_matches_predicate?(record, context, predicate)
          end

          count >= minimum
        end

        def fci_flag_present?(context, clause)
          RegistrationValidators.fci_flag_present?(context.citizen, clause.fetch("flag"))
        end

        def microarea_linked?(context)
          RegistrationValidators.microarea_linked?(context.citizen)
        end

        def clinical_predicate?(context, clause)
          record_types = Array(clause["record_types"]).map(&:to_s)
          within_months = clause.fetch("within_months", 6).to_i
          window_start = context.reference_date - within_months.months
          predicate = clause.fetch("predicate", {})

          clinical_records_for(context.citizen, record_types, since: window_start, context: context).any? do |record|
            encounter_date = encounter_date_for(record, context)
            next false unless encounter_date

            payloads_for_record(record, context.citizen).any? do |payload|
              predicate_matches?(predicate, payload, record_type: record.record_type)
            end
          end
        end

        def emulti_encounter_count?(context, clause)
          minimum = clause.fetch("minimum_count", 1).to_i
          record_types = Array(clause.fetch("record_types", %w[FAC FAI FAO])).map(&:to_s)
          within_months = clause.fetch("within_months", 3).to_i

          count = records_in_window(context, record_types, within_months).count do |record|
            payloads_for_record(record, context.citizen).any? do |payload|
              emulti_attendance?(payload, record.record_type)
            end
          end

          count >= minimum
        end

        def appointment_in_quadrimester?(context, clause)
          statuses = Array(clause.fetch("statuses", %w[scheduled checked_in completed]))
          scoped_appointments(context).where(status: statuses).exists?
        end

        def encounter_in_window?(context, clause)
          within_months = clause.fetch("within_months", 12).to_i
          window_start = context.reference_date - within_months.months

          Encounter
            .where(municipality_id: context.municipality_id, citizen_id: context.citizen.id)
            .where("encounter_at >= ?", window_start.beginning_of_day)
            .exists?
        end

        def count_records_in_window(context, record_types, within_months)
          records_in_window(context, record_types, within_months).count
        end

        def records_in_window(context, record_types, within_months)
          window_start = context.reference_date - within_months.months
          clinical_records_for(context.citizen, record_types, since: window_start, context: context)
        end

        def record_dates_in_window(context, record_types, within_months)
          records_in_window(context, record_types, within_months).filter_map do |record|
            encounter_date_for(record, context)
          end
        end

        def record_dates_between(context, record_types, start_date:, end_date:)
          clinical_records_for(context.citizen, record_types, since: start_date, context: context).filter_map do |record|
            date = encounter_date_for(record, context)
            next unless date
            next unless date <= end_date

            date
          end
        end

        def scoped_appointments(context)
          range = context.quadrimester_range
          Appointment
            .where(municipality_id: context.municipality_id, citizen_id: context.citizen.id)
            .where(scheduled_at: range.begin.beginning_of_day..range.end.end_of_day)
        end

        def clinical_records_for(citizen, record_types, since: nil, context: nil)
          record_ids = clinical_record_ids_for(citizen, context, record_types: record_types)
          return ClinicalRecord.none if record_ids.empty?

          scope = ClinicalRecord
            .where(municipality_id: citizen.municipality_id, validation_status: "valid", record_type: record_types, id: record_ids)
          if since
            since_time = since.beginning_of_day
            scope = scope.joins(linked_encounters_join_sql(citizen)).where(
              <<~SQL.squish,
                GREATEST(
                  COALESCE(clinical_records.encounter_at, TIMESTAMPTZ '-infinity'),
                  COALESCE(linked_encounters.max_encounter_at, TIMESTAMPTZ '-infinity')
                ) >= ?
              SQL
              since_time
            )
          end
          scope
        end

        def clinical_record_ids_for(citizen, context, record_types: nil)
          return fetch_clinical_record_ids(citizen, record_types: record_types) unless context

          types_key = Array(record_types).map(&:to_s).sort
          by_citizen = context.cache[:clinical_record_ids_by_citizen] ||= {}
          by_types = by_citizen[citizen.id] ||= {}
          by_types[types_key] ||= fetch_clinical_record_ids(citizen, record_types: record_types)
        end

        def fetch_clinical_record_ids(citizen, record_types: nil)
          types = Array(record_types).map(&:to_s).presence
          encounter_record_ids = Encounter
            .where(municipality_id: citizen.municipality_id, citizen_id: citizen.id)
            .where.not(clinical_record_id: nil)
          encounter_record_ids = encounter_record_ids.where(record_type: types) if types
          encounter_record_ids = encounter_record_ids.pluck(:clinical_record_id)

          direct_ids = []
          if citizen.clinical_record_id.present?
            direct_ids = if types
              ClinicalRecord.where(
                municipality_id: citizen.municipality_id,
                id: citizen.clinical_record_id,
                record_type: types
              ).pluck(:id)
            else
              [ citizen.clinical_record_id ]
            end
          end

          (direct_ids + encounter_record_ids).uniq
        end

        def linked_encounters_join_sql(citizen)
          ActiveRecord::Base.sanitize_sql_array(
            [
              <<~SQL.squish,
                LEFT JOIN (
                  SELECT clinical_record_id, MAX(encounter_at) AS max_encounter_at
                  FROM encounters
                  WHERE municipality_id = ?
                    AND citizen_id = ?
                  GROUP BY clinical_record_id
                ) linked_encounters ON linked_encounters.clinical_record_id = clinical_records.id
              SQL
              citizen.municipality_id,
              citizen.id
            ]
          )
        end

        def encounter_at_by_record_id(context)
          by_citizen = context.cache[:encounter_at_by_record_id] ||= {}
          by_citizen[context.citizen.id] ||= Encounter
            .where(municipality_id: context.municipality_id, citizen_id: context.citizen.id)
            .where.not(clinical_record_id: nil)
            .group(:clinical_record_id)
            .maximum(:encounter_at)
        end

        def encounter_at_for(record, context)
          linked = context ? encounter_at_by_record_id(context)[record.id] : nil
          [ record.encounter_at, linked ].compact.max
        end

        def encounter_date_for(record, context)
          encounter_at_for(record, context)&.to_date
        end

        def payloads_for_record(record, citizen)
          items = record.clinical_record_items.where(citizen_cpf: citizen.cpf).to_a
          return items.map(&:payload_json) if items.any?

          [ record.payload_json ]
        end

        def anthropometry_present?(payload, record_type)
          PayloadSections.each_section(payload, record_type: record_type).any? do |section|
            weight = PayloadSections.dig(section, "medicoes.peso") ||
                     PayloadSections.dig(section, "pesoAcompanhamentoNutricional") ||
                     PayloadSections.dig(section, "peso")
            height = PayloadSections.dig(section, "medicoes.altura") ||
                     PayloadSections.dig(section, "alturaAcompanhamentoNutricional") ||
                     PayloadSections.dig(section, "altura")
            weight.present? && height.present?
          end
        end

        def blood_pressure_present?(payload, record_type)
          PayloadSections.each_section(payload, record_type: record_type).any? do |section|
            sys = PayloadSections.dig(section, "medicoes.pressaoArterialSistolica") ||
                  PayloadSections.dig(section, "pressaoSistolica") ||
                  PayloadSections.dig(section, "pressao_sistolica")
            dia = PayloadSections.dig(section, "medicoes.pressaoArterialDiastolica") ||
                  PayloadSections.dig(section, "pressaoDiastolica") ||
                  PayloadSections.dig(section, "pressao_diastolica")
            sys.present? && dia.present?
          end
        end

        def vaccination_match?(payload, target, immunobiological_code: nil, dose_code: nil, aliases: nil)
          vaccination_entries = extract_vaccination_entries(payload)
          Array(vaccination_entries).any? do |vaccination_entry|
            next false unless vaccination_entry.is_a?(Hash) || vaccination_entry.is_a?(String)

            entry = vaccination_entry.is_a?(Hash) ? vaccination_entry : { "imunobiologico" => vaccination_entry.to_s }
            name = entry["imunobiologico"] || entry["nomeImunobiologico"] || entry["descricao"] || entry.to_s
            code = entry["codigoImunobiologico"] || entry["codigo_imunobiologico"] ||
                   entry["codigoVacina"] || entry["codigo_vacina"] || entry["codigo"] ||
                   numeric_code(entry["imunobiologico"])

            if immunobiological_code.present?
              next true if vaccination_dose_match_entry?(
                entry,
                immunobiological_code: immunobiological_code,
                dose_code: dose_code,
                aliases: aliases
              )

              # C3.F/C7.C: name fallback when dose/code match fails but clause has no strict code target.
              next true if target.blank?

              next strict_immunobiological_match?(name, target, code: code, aliases: aliases)
            end

            next true if target.blank?

            strict_immunobiological_match?(name, target, code: code, aliases: aliases)
          end
        end

        def vaccination_dose_match?(payload, immunobiological_code:, dose_code: nil, aliases: nil)
          extract_vaccination_entries(payload).any? do |entry|
            vaccination_dose_match_entry?(
              entry,
              immunobiological_code: immunobiological_code,
              dose_code: dose_code,
              aliases: aliases
            )
          end
        end

        def extract_vaccination_entries(payload)
          nested = Array(payload["vacinacoes"]).flat_map do |section|
            next [] unless section.is_a?(Hash)

            Array(section["vacinas"])
          end
          flat = payload["vacinas"] || payload["vacina"] || payload["imunobiologicos"]
          nested + Array(flat)
        end

        def vaccination_dose_match_entry?(entry, immunobiological_code:, dose_code: nil, aliases: nil)
          return false unless entry.is_a?(Hash)

          name = entry["imunobiologico"] || entry["nomeImunobiologico"] || entry["descricao"]
          code = entry["codigoImunobiologico"] || entry["codigo_imunobiologico"] ||
                 entry["codigoVacina"] || entry["codigo_vacina"] || entry["codigo"] ||
                 numeric_code(entry["imunobiologico"])
          dose = entry["dose"] || entry["dose_label"]

          code_match = vaccine_code_matches?(code, immunobiological_code) ||
                       alias_match?(name, aliases: aliases)
          return false unless code_match
          return true if dose_code.blank?

          dose_codes_match?(dose, dose_code)
        end

        def numeric_code(value)
          return nil unless value.is_a?(Numeric) || value.to_s.match?(/\A\d+\z/)

          value.to_s
        end

        def alias_match?(name, aliases: nil)
          return false if name.blank? && aliases.blank?

          tokens = Array(aliases).map { |token| token.to_s.downcase }
          normalized_name = name.to_s.downcase
          tokens.any? { |token| normalized_name.include?(token) }
        end

        def dose_codes_match?(actual, expected)
          PniCodeNormalizer.normalize_dose_code(actual) == PniCodeNormalizer.normalize_dose_code(expected)
        end

        def vaccine_code_matches?(code, expected)
          return false if code.blank? || expected.blank?

          PniCodeNormalizer.normalize_code(code) == PniCodeNormalizer.normalize_code(expected)
        end

        def strict_immunobiological_match?(name, target, code: nil, aliases: nil)
          normalized_name = name.to_s.downcase
          if aliases.present? && alias_match?(name, aliases: aliases)
            return true
          end

          case target.to_s.downcase
          when "dtpa"
            return true if code.present? && LediPayloadPaths::DTPA_VACCINE_CODES.include?(PniCodeNormalizer.normalize_code(code))

            normalized_name.match?(/\b(d[\s\-]?tpa|tr[ií]plice bacteriana acelular)\b/i)
          when "influenza"
            normalized_name.match?(/\b(influenza|gripe)\b/i)
          when "hpv"
            normalized_name.match?(/\bhpv\b/i)
          else
            normalized_name.include?(target.to_s.downcase)
          end
        end

        def parse_date(value)
          return value if value.is_a?(Date)

          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def record_matches_predicate?(record, context, predicate)
          payloads_for_record(record, context.citizen).any? do |payload|
            predicate_matches?(predicate, payload, record_type: record.record_type)
          end
        end

        def gestational_measure_present?(record, context, measure, predicate)
          payloads_for_record(record, context.citizen).any? do |payload|
            case measure
            when "consult", "visit"
              predicate.present? && predicate_matches?(predicate, payload, record_type: record.record_type)
            when "blood_pressure"
              blood_pressure_present?(payload, record.record_type)
            when "anthropometry"
              anthropometry_present?(payload, record.record_type)
            else
              false
            end
          end
        end

        def predicate_matches?(predicate, payload, record_type:)
          case predicate["type"]
          when "procedure_present" then procedure_present?(payload, predicate.fetch("code"))
          when "procedure_any_present" then procedure_any_present?(payload, predicate.fetch("codes"))
          when "present"
            aliases = LediPayloadPaths.payload_field_aliases(predicate.fetch("field_path"))
            PayloadSections.each_section(payload, record_type: record_type).any? do |section|
              aliases.any? { |field_path| PayloadSections.dig(section, field_path).present? }
            end
          when "dental_first_consult" then dental_first_consult?(payload, predicate)
          when "dental_treatment_completed" then dental_treatment_completed?(payload, predicate)
          when "supervised_brushing" then supervised_brushing?(payload, record_type: record_type)
          when "preventive_procedure" then preventive_procedure?(payload)
          when "tra_procedure" then tra_procedure?(payload)
          when "interprofessional_action" then interprofessional_action?(payload, record_type: record_type)
          when "emulti_attendance" then emulti_attendance?(payload, record_type)
          else
            false
          end
        end

        def dental_first_consult?(payload, predicate)
          codes = Array(predicate.fetch("consult_type_codes", LediPayloadPaths::DENTAL_FIRST_CONSULT_TYPE_CODES))
          PayloadSections.list_includes?(payload, %w[tiposConsultaOdonto tipos_consulta_odonto], codes)
        end

        def dental_treatment_completed?(payload, predicate)
          codes = Array(predicate.fetch("encam_codes", LediPayloadPaths::DENTAL_TREATMENT_COMPLETE_ENC_CODES))
          PayloadSections.list_includes?(payload, %w[tiposEncamOdonto tipos_encam_odonto], codes)
        end

        def supervised_brushing?(payload, record_type:)
          practice_code = LediPayloadPaths::SUPERVISED_BRUSHING_PRACTICE_CODE
          PayloadSections.list_includes?(
            payload,
            %w[praticasEmSaude praticas_em_saude],
            [ practice_code, practice_code.to_s ]
          )
        end

        def preventive_procedure?(payload)
          PayloadSections.procedure_matches_prefixes?(payload, LediPayloadPaths::PREVENTIVE_PROCEDURE_CODE_PREFIXES)
        end

        def tra_procedure?(payload)
          LediPayloadPaths::TRA_PROCEDURE_CODE_PREFIXES.any? { |code| procedure_present?(payload, code) } ||
            PayloadSections.procedure_matches_prefixes?(payload, LediPayloadPaths::TRA_PROCEDURE_CODE_PREFIXES)
        end

        def interprofessional_action?(payload, record_type:)
          case record_type.to_s
          when "FAC"
            professionals = PayloadSections.dig(payload, "profissionais")
            prof_count = Array(professionals).size
            prof_count >= 2 ||
              PayloadSections.dig(payload, "atividadeTipo").present? ||
              PayloadSections.dig(payload, "atividade_tipo").present?
          when "FCC"
            PayloadSections.dig(payload, "condutaEvolucao").present? ||
              PayloadSections.dig(payload, "conduta_evolucao").present? ||
              PayloadSections.dig(payload, "evolucoes").present?
          else
            false
          end
        end

        def emulti_attendance?(payload, record_type)
          PayloadSections.each_section(payload, record_type: record_type) do |section|
            Array(section["profissionais"]).each do |prof|
              cbo = prof["codigoCbo2002"] || prof["codigo_cbo2002"]
              next if cbo.blank?

              return true if LediPayloadPaths::EMULTI_CBO_PREFIXES.any? { |prefix| cbo.to_s.start_with?(prefix) }
            end
          end

          header = payload["headerTransport"] || payload["header_transport"]
          cbo = header&.dig("cboCodigo_2002") || header&.dig("cbo_codigo_2002")
          cbo.present? && LediPayloadPaths::EMULTI_CBO_PREFIXES.any? { |prefix| cbo.to_s.start_with?(prefix) }
        end

        def procedure_present?(payload, code)
          normalized = code.to_s.gsub(/\D/, "")
          PayloadSections.deep_values(payload).any? do |value|
            value.to_s.gsub(/\D/, "") == normalized
          end
        end

        def procedure_any_present?(payload, codes)
          Array(codes).any? { |code| procedure_present?(payload, code) }
        end

        def age_in_months(birth_date, reference_date)
          months = (reference_date.year - birth_date.year) * 12 + (reference_date.month - birth_date.month)
          months -= 1 if reference_date.day < birth_date.day
          months
        end
      end
    end
  end
end

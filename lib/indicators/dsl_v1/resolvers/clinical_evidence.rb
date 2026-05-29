# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module ClinicalEvidence
        module_function

        def matches?(clause, context)
          case clause["type"]
          when "registration_complete"
            registration_complete?(context)
          when "registration_updated_mici"
            registration_updated_mici?(context, clause)
          when "registration_within_team_limit"
            registration_within_team_limit?(context, clause)
          when "clinical_predicate"
            clinical_predicate?(context, clause)
          when "appointment_in_quadrimester"
            appointment_in_quadrimester?(context, clause)
          when "encounter_in_window"
            encounter_in_window?(context, clause)
          when "emulti_encounter_count"
            emulti_encounter_count?(context, clause)
          else
            false
          end
        end

        def registration_complete?(context)
          citizen = context.citizen
          citizen.cpf.present? &&
            citizen.birth_date.present? &&
            citizen.care_team_id.present? &&
            citizen.full_name.present?
        end

        def registration_updated_mici?(context, clause)
          return false unless registration_complete?(context)

          within_months = clause.fetch("within_months", 24).to_i
          window_start = context.reference_date - within_months.months
          context.citizen.updated_at.to_date >= window_start
        end

        def registration_within_team_limit?(context, clause)
          return false unless registration_complete?(context)

          limit = clause.fetch("team_limit", 3_500).to_i
          team_id = context.citizen.care_team_id
          return true if team_id.blank?

          Citizen.where(municipality_id: context.municipality_id, care_team_id: team_id).count <= limit
        end

        def clinical_predicate?(context, clause)
          record_types = Array(clause["record_types"]).map(&:to_s)
          within_months = clause.fetch("within_months", 6).to_i
          window_start = context.reference_date - within_months.months
          predicate = clause.fetch("predicate", {})

          clinical_records_for(context.citizen, record_types).any? do |record|
            next false if record.encounter_at.present? && record.encounter_at.to_date < window_start

            payloads_for_record(record, context.citizen).any? do |payload|
              predicate_matches?(predicate, payload, record_type: record.record_type)
            end
          end
        end

        def emulti_encounter_count?(context, clause)
          minimum = clause.fetch("minimum_count", 1).to_i
          record_types = Array(clause.fetch("record_types", %w[FAC FAI FAO])).map(&:to_s)
          within_months = clause.fetch("within_months", 3).to_i
          window_start = context.reference_date - within_months.months

          count = clinical_records_for(context.citizen, record_types).count do |record|
            next false if record.encounter_at.present? && record.encounter_at.to_date < window_start

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

        def scoped_appointments(context)
          range = context.quadrimester_range
          Appointment
            .where(municipality_id: context.municipality_id, citizen_id: context.citizen.id)
            .where(scheduled_at: range.begin.beginning_of_day..range.end.end_of_day)
        end

        def clinical_records_for(citizen, record_types)
          encounter_record_ids = Encounter
            .where(municipality_id: citizen.municipality_id, citizen_id: citizen.id)
            .where.not(clinical_record_id: nil)
            .pluck(:clinical_record_id)

          direct_ids = citizen.clinical_record_id.present? ? [ citizen.clinical_record_id ] : []
          record_ids = (direct_ids + encounter_record_ids).uniq
          return ClinicalRecord.none if record_ids.empty?

          ClinicalRecord
            .where(municipality_id: citizen.municipality_id, validation_status: "valid", record_type: record_types, id: record_ids)
        end

        def payloads_for_record(record, citizen)
          items = record.clinical_record_items.where(citizen_cpf: citizen.cpf)
          return items.map(&:payload_json) if items.exists?

          [ record.payload_json ]
        end

        def predicate_matches?(predicate, payload, record_type:)
          case predicate["type"]
          when "procedure_present"
            procedure_present?(payload, predicate.fetch("code"))
          when "present"
            aliases = LediPayloadPaths.payload_field_aliases(predicate.fetch("field_path"))
            PayloadSections.each_section(payload, record_type: record_type).any? do |section|
              aliases.any? { |field_path| PayloadSections.dig(section, field_path).present? }
            end
          when "dental_first_consult"
            dental_first_consult?(payload, predicate)
          when "dental_treatment_completed"
            dental_treatment_completed?(payload, predicate)
          when "supervised_brushing"
            supervised_brushing?(payload, record_type: record_type)
          when "preventive_procedure"
            preventive_procedure?(payload)
          when "tra_procedure"
            tra_procedure?(payload)
          when "interprofessional_action"
            interprofessional_action?(payload, record_type: record_type)
          when "emulti_attendance"
            emulti_attendance?(payload, record_type)
          else
            false
          end
        end

        def dental_first_consult?(payload, predicate)
          codes = Array(predicate.fetch("consult_type_codes", LediPayloadPaths::DENTAL_FIRST_CONSULT_TYPE_CODES))
          PayloadSections.list_includes?(
            payload,
            %w[tiposConsultaOdonto tipos_consulta_odonto],
            codes
          )
        end

        def dental_treatment_completed?(payload, predicate)
          codes = Array(predicate.fetch("encam_codes", LediPayloadPaths::DENTAL_TREATMENT_COMPLETE_ENC_CODES))
          PayloadSections.list_includes?(
            payload,
            %w[tiposEncamOdonto tipos_encam_odonto],
            codes
          )
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
          exact = LediPayloadPaths::TRA_PROCEDURE_CODE_PREFIXES
          exact.any? { |code| procedure_present?(payload, code) } ||
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
            profs = section["profissionais"] || section["profissionais"]
            Array(profs).each do |prof|
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
          normalized = code.to_s
          PayloadSections.deep_values(payload).any? do |value|
            value.to_s.gsub(/\D/, "") == normalized.gsub(/\D/, "")
          end
        end
      end
    end
  end
end

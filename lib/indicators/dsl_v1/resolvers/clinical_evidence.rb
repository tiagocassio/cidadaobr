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
          when "clinical_predicate"
            clinical_predicate?(context, clause)
          when "appointment_in_quadrimester"
            appointment_in_quadrimester?(context, clause)
          when "encounter_in_window"
            encounter_in_window?(context, clause)
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

        def clinical_predicate?(context, clause)
          record_types = Array(clause["record_types"]).map(&:to_s)
          within_months = clause.fetch("within_months", 6).to_i
          window_start = context.reference_date - within_months.months
          predicate = clause.fetch("predicate", {})

          clinical_records_for(context.citizen, record_types).any? do |record|
            next false if record.encounter_at.present? && record.encounter_at.to_date < window_start

            predicate_matches?(predicate, record.payload_json)
          end
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
            .select(:clinical_record_id)

          direct_ids = citizen.clinical_record_id.present? ? [ citizen.clinical_record_id ] : []
          record_ids = (direct_ids + encounter_record_ids.to_a).uniq
          return ClinicalRecord.none if record_ids.empty?

          ClinicalRecord
            .where(municipality_id: citizen.municipality_id, validation_status: "valid", record_type: record_types, id: record_ids)
        end

        def predicate_matches?(predicate, payload)
          case predicate["type"]
          when "procedure_present"
            procedure_present?(payload, predicate.fetch("code"))
          when "present"
            field_path = LediPayloadPaths.payload_field(predicate.fetch("field_path"))
            dig(payload, field_path).present?
          else
            false
          end
        end

        def procedure_present?(payload, code)
          normalized = code.to_s
          deep_values(payload).any? do |value|
            value.to_s.gsub(/\D/, "") == normalized.gsub(/\D/, "")
          end
        end

        def deep_values(object)
          case object
          when Hash
            object.values.flat_map { |value| deep_values(value) }
          when Array
            object.flat_map { |value| deep_values(value) }
          else
            [ object ]
          end
        end

        def dig(payload, path)
          path.to_s.split(".").reduce(payload) do |current, segment|
            break nil if current.nil?

            current[segment] || current[segment.camelize(:lower)] || current[segment.camelize]
          end
        end
      end
    end
  end
end

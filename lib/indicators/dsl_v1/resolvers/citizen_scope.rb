# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module CitizenScope
        module_function

        def matches?(clause, context)
          case clause["type"]
          when "citizens_on_team"
            citizen_on_team?(context, clause)
          when "citizens_with_condition"
            citizen_with_condition?(context, clause)
          when "citizens_age_gte"
            citizens_age_gte?(context, clause)
          when "citizens_sex_female"
            citizens_sex_female?(context)
          else
            false
          end
        end

        def citizen_on_team?(context, clause)
          return false if context.citizen.care_team_id.blank?

          expected_team_id = clause["care_team_id"]
          return true if expected_team_id.blank?

          context.citizen.care_team_id.to_s == expected_team_id.to_s
        end

        def citizen_with_condition?(context, clause)
          flag = clause.fetch("flag").to_s
          payload = latest_fci_payload(context.citizen)
          return false if payload.blank?

          condition_truthy?(payload, flag)
        end

        def citizens_age_gte?(context, clause)
          min_age = clause.fetch("min_age", 60).to_i
          birth_date = context.citizen.birth_date
          return false unless birth_date

          age = context.reference_date.year - birth_date.year
          age -= 1 if context.reference_date < birth_date + age.years
          age >= min_age
        end

        def citizens_sex_female?(context)
          context.citizen.sex.to_s.in?(LediPayloadPaths::FEMALE_SEX_VALUES)
        end

        def latest_fci_payload(citizen)
          if citizen.clinical_record&.record_type == "FCI"
            return citizen.clinical_record.payload_json
          end

          ClinicalRecord
            .where(municipality_id: citizen.municipality_id, record_type: "FCI", validation_status: "valid")
            .joins(:citizen)
            .where(citizens: { id: citizen.id })
            .order(updated_at: :desc)
            .first
            &.payload_json
        end

        def condition_truthy?(payload, flag)
          candidates = LediPayloadPaths.fci_condition_field_aliases(flag)
          sections = LediPayloadPaths::FCI_HEALTH_CONDITION_SECTIONS.filter_map { |key| payload[key] } + [ payload ]

          sections.any? do |section|
            next false unless section.is_a?(Hash)

            candidates.any? { |key| truthy?(dig(section, key)) }
          end
        end

        def dig(payload, path)
          path.to_s.split(".").reduce(payload) do |current, segment|
            break nil if current.nil?

            current[segment] || current[segment.camelize(:lower)] || current[segment.camelize]
          end
        end

        def truthy?(value)
          return false if value.nil?

          case value
          when true then true
          when false, nil then false
          when Numeric then value.to_i.positive?
          when String then !value.strip.empty? && value.strip != "0" && value.strip.downcase != "false"
          else value.present?
          end
        end
      end
    end
  end
end

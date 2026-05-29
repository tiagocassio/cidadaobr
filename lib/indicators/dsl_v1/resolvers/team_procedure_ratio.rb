# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module TeamProcedureRatio
        module_function

        def score(care_team_id:, municipality_id:, quadrimester:, numerator_prefixes:)
          range = Indicators::Quadrimester.range_for(quadrimester)
          extraction = 0
          total = 0

          ClinicalRecord
            .where(
              municipality_id: municipality_id,
              care_team_id: care_team_id,
              validation_status: "valid",
              record_type: "FAO"
            )
            .where(encounter_at: range.begin.beginning_of_day..range.end.end_of_day)
            .find_each do |record|
              procedures = extract_procedure_codes(record.payload_json)
              procedures.each do |code|
                total += 1
                extraction += 1 if extraction_code?(code, numerator_prefixes)
              end
            end

          return 0.0 if total.zero?

          ratio = (extraction.to_f / total) * 100
          [ 100.0 - ratio, 0.0 ].max.round(2)
        end

        def extract_procedure_codes(payload)
          codes = []
          PayloadSections.each_section(payload, record_type: "FAO") do |section|
            list = section["procedimentosRealizados"] || section["procedimentos_realizados"] || []
            Array(list).each do |entry|
              code = entry["coMsProcedimento"] || entry["co_ms_procedimento"] || entry["codigo"]
              codes << code.to_s.gsub(/\D/, "") if code.present?
            end
          end
          codes
        end

        def extraction_code?(code, prefixes)
          digits = code.to_s.gsub(/\D/, "")
          Array(prefixes).any? { |prefix| digits.start_with?(prefix.to_s.gsub(/\D/, "")) }
        end
      end
    end
  end
end

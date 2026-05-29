# frozen_string_literal: true

module Indicators
  module DslV1
    class Evaluator
      Result = Data.define(:in_denominator, :meets_numerator, :good_practice_code)

      class << self
        def evaluate(expression:, context:)
          return Result.new(in_denominator: false, meets_numerator: false, good_practice_code: nil) unless dsl_v1?(expression)

          in_denominator = denominator_match?(expression.fetch("denominator"), context)
          meets_numerator = in_denominator && numerator_match?(expression.fetch("numerator"), context)

          Result.new(
            in_denominator: in_denominator,
            meets_numerator: meets_numerator,
            good_practice_code: expression["good_practice_code"]
          )
        end

        def team_score(expression:, citizens:, quadrimester:, reference_date: Date.current, care_team_id: nil)
          return 0.0 if citizens.blank?

          if expression["team_score_mode"] == "procedure_ratio"
            team_id = care_team_id || citizens.limit(1).pick(:care_team_id)
            municipality_id = citizens.limit(1).pick(:municipality_id)
            return 0.0 if team_id.blank?

            return Resolvers::TeamProcedureRatio.score(
              care_team_id: team_id,
              municipality_id: municipality_id,
              quadrimester: quadrimester,
              numerator_prefixes: expression.dig("numerator", "extraction_prefixes") ||
                LediPayloadPaths::EXTRACTION_PROCEDURE_CODE_PREFIXES
            )
          end

          denominator_count = 0
          numerator_count = 0

          citizens.find_each do |citizen|
            context = Context.new(
              citizen: citizen,
              care_team: citizen.care_team,
              quadrimester: quadrimester,
              reference_date: reference_date
            )
            result = evaluate(expression: expression, context: context)
            next unless result.in_denominator

            denominator_count += 1
            numerator_count += 1 if result.meets_numerator
          end

          return 0.0 if denominator_count.zero?

          ((numerator_count.to_f / denominator_count) * 100).round(2)
        end

        def dsl_v1?(expression)
          expression.is_a?(Hash) && expression["version"] == "dsl_v1"
        end

        private

        def denominator_match?(clause, context)
          ::Indicators::DslV1::Resolvers::CitizenScope.matches?(clause, context)
        end

        def numerator_match?(clause, context)
          ::Indicators::DslV1::Resolvers::ClinicalEvidence.matches?(clause, context)
        end
      end
    end
  end
end

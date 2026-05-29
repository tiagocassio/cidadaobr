# frozen_string_literal: true

module Indicators
  module DslV1
    class Evaluator
      Result = Data.define(:in_denominator, :meets_numerator, :good_practice_code)

      class << self
        def evaluate(expression:, context:)
          return Result.new(in_denominator: false, meets_numerator: false, good_practice_code: nil) unless dsl_v1?(expression)
          return Result.new(in_denominator: false, meets_numerator: false, good_practice_code: nil) if expression["team_score_mode"] == "linkage_aggregate"

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

          if expression["team_score_mode"] == "linkage_aggregate"
            return linkage_aggregate_score(
              expression: expression,
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team_id: care_team_id
            )
          end

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

        def linkage_aggregate_score(expression:, citizens:, quadrimester:, reference_date:, care_team_id:)
          components = expression.fetch("linkage_components")
          weighted_sum = 0.0
          weight_total = 0.0

          components.each do |component|
            code = component.fetch("code")
            weight = component.fetch("weight").to_f
            child_rule = RuleCatalog.dsl_v1_rules(indicator_codes: [ code ]).first
            unless child_rule
              raise ArgumentError, "linkage_aggregate missing dsl_v1 rule for indicator #{code.inspect}"
            end

            child_score = team_score(
              expression: child_rule.expression,
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team_id: care_team_id
            )
            weighted_sum += child_score * weight
            weight_total += weight
          end

          return 0.0 if weight_total.zero?

          # EPIC-05: replace renormalization with fixed MS weights when V_SAT joins CVAT (see plan Camada II).
          (weighted_sum / weight_total).round(2)
        end
      end
    end
  end
end

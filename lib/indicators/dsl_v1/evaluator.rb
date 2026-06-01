# frozen_string_literal: true

module Indicators
  module DslV1
    class Evaluator
      Result = Data.define(:in_denominator, :meets_numerator, :good_practice_code)

      class << self
        def evaluate(expression:, context:)
          return empty_result unless dsl_v1?(expression)
          return empty_result if aggregate_only?(expression)

          in_denominator = denominator_match?(expression.fetch("denominator"), context)
          meets_numerator = in_denominator && numerator_match?(expression.fetch("numerator"), context)

          Result.new(
            in_denominator: in_denominator,
            meets_numerator: meets_numerator,
            good_practice_code: expression["good_practice_code"]
          )
        end

        def team_score(expression:, citizens:, quadrimester:, reference_date: Date.current, care_team_id: nil, care_team: nil)
          return 0.0 if citizens.blank?

          case expression["team_score_mode"]
          when "linkage_aggregate"
            linkage_aggregate_score(
              expression: expression,
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team_id: care_team_id,
              care_team: care_team
            )
          when "procedure_ratio"
            procedure_ratio_score(expression: expression, citizens: citizens, quadrimester: quadrimester, care_team_id: care_team_id)
          when "programmed_attendance_ratio"
            programmed_attendance_ratio_score(
              citizens: citizens,
              quadrimester: quadrimester,
              care_team_id: care_team_id
            )
          when "good_practices_pct"
            good_practices_pct_score(
              indicator_code: expression.fetch("indicator_code"),
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team_id: care_team_id,
              care_team: care_team
            )
          else
            standard_pct_score(
              expression: expression,
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team: care_team
            )
          end
        end

        def good_practices_pct_score(indicator_code:, citizens:, quadrimester:, reference_date: Date.current, care_team_id: nil, care_team: nil)
          rules = bp_rules_for(indicator_code, care_team_id: care_team_id, care_team: care_team)
          return 0.0 if rules.empty?

          total_applicable = 0
          total_met = 0
          cache = {}

          citizens.find_each do |citizen|
            context = Context.new(
              citizen: citizen,
              care_team: care_team,
              quadrimester: quadrimester,
              reference_date: reference_date,
              cache: cache
            )
            rules.each do |rule|
              result = evaluate(expression: rule.expression, context: context)
              next unless result.in_denominator

              total_applicable += 1
              total_met += 1 if result.meets_numerator
            end
          end

          return 0.0 if total_applicable.zero?

          ((total_met.to_f / total_applicable) * 100).round(2)
        end

        def dsl_v1?(expression)
          expression.is_a?(Hash) && expression["version"] == "dsl_v1"
        end

        private

        def empty_result
          Result.new(in_denominator: false, meets_numerator: false, good_practice_code: nil)
        end

        def aggregate_only?(expression)
          expression["team_score_mode"] == "linkage_aggregate"
        end

        def denominator_match?(clause, context)
          ::Indicators::DslV1::Resolvers::CitizenScope.matches?(clause, context)
        end

        def numerator_match?(clause, context)
          ::Indicators::DslV1::Resolvers::ClinicalEvidence.matches?(clause, context)
        end

        def standard_pct_score(expression:, citizens:, quadrimester:, reference_date:, care_team: nil)
          denominator_count = 0
          numerator_count = 0
          cache = {}

          citizens.find_each do |citizen|
            context = Context.new(
              citizen: citizen,
              care_team: care_team,
              quadrimester: quadrimester,
              reference_date: reference_date,
              cache: cache
            )
            result = evaluate(expression: expression, context: context)
            next unless result.in_denominator

            denominator_count += 1
            numerator_count += 1 if result.meets_numerator
          end

          return 0.0 if denominator_count.zero?

          ((numerator_count.to_f / denominator_count) * 100).round(2)
        end

        def procedure_ratio_score(expression:, citizens:, quadrimester:, care_team_id:)
          team_id = care_team_id || citizens.limit(1).pick(:care_team_id)
          municipality_id = citizens.limit(1).pick(:municipality_id)
          return 0.0 if team_id.blank?

          Resolvers::TeamProcedureRatio.score(
            care_team_id: team_id,
            municipality_id: municipality_id,
            quadrimester: quadrimester,
            numerator_prefixes: expression.dig("numerator", "extraction_prefixes") ||
              LediPayloadPaths::EXTRACTION_PROCEDURE_CODE_PREFIXES
          )
        end

        def programmed_attendance_ratio_score(citizens:, quadrimester:, care_team_id:)
          team_id = care_team_id || citizens.limit(1).pick(:care_team_id)
          municipality_id = citizens.limit(1).pick(:municipality_id)
          return 0.0 if team_id.blank?

          range = Quadrimester.range_for(quadrimester)
          scope = Appointment.where(municipality_id: municipality_id, care_team_id: team_id)
            .where(scheduled_at: range.begin.beginning_of_day..range.end.end_of_day)
            .where(status: "completed")
          total, programmed = scope.pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(*) FILTER (WHERE kind = 'scheduled')")
          )
          return 0.0 if total.to_i.zero?

          # C1 Nota: numerador = atendimentos programados concluídos; denominador = todos concluídos no quadrimestre.
          ((programmed.to_f / total) * 100).round(2)
        end

        def linkage_aggregate_score(expression:, citizens:, quadrimester:, reference_date:, care_team_id:, care_team: nil)
          care_team ||= CareTeam.find_by(id: care_team_id) if care_team_id.present?

          if expression["linkage_monthly_average"]
            monthly_scores = monthly_reference_dates(quadrimester, reference_date).map do |month_end|
              compute_linkage_aggregate_score(
                expression: expression,
                citizens: citizens,
                quadrimester: quadrimester,
                reference_date: month_end,
                care_team_id: care_team_id,
                care_team: care_team,
                skip_sat_bonus: true
              )
            end
            base_score = (monthly_scores.sum / monthly_scores.size.to_f).round(2)
            return apply_linkage_sat_bonus(
              expression: expression,
              base_score: base_score,
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team_id: care_team_id,
              care_team: care_team,
              ms_scale: expression["score_scale"] == "ms_0_10"
            )
          end

          compute_linkage_aggregate_score(
            expression: expression,
            citizens: citizens,
            quadrimester: quadrimester,
            reference_date: reference_date,
            care_team_id: care_team_id,
            care_team: care_team
          )
        end

        def compute_linkage_aggregate_score(expression:, citizens:, quadrimester:, reference_date:, care_team_id:, care_team: nil, skip_sat_bonus: false)
          components = expression.fetch("linkage_components")
          ms_scale = expression["score_scale"] == "ms_0_10"
          weighted_sum = 0.0
          weight_total = components.sum { |c| c.fetch("weight").to_f } unless ms_scale

          components.each do |component|
            code = component.fetch("code")
            weight = component.fetch("weight").to_f
            resolved = child_indicator_team_score(
              code: code,
              citizens: citizens,
              quadrimester: quadrimester,
              reference_date: reference_date,
              care_team_id: care_team_id,
              care_team: care_team
            )
            unless resolved
              raise ArgumentError, "linkage_aggregate missing dsl_v1 rule for indicator #{code.inspect}"
            end

            child_score, child_expression = resolved

            if ms_scale
              weighted_sum += (child_score / score_scale_divisor(child_expression)) * weight
            else
              next if weight_total.zero?

              weighted_sum += child_score * (weight / weight_total)
            end
          end

          base_score = weighted_sum.round(2)
          return base_score if skip_sat_bonus

          apply_linkage_sat_bonus(
            expression: expression,
            base_score: base_score,
            citizens: citizens,
            quadrimester: quadrimester,
            reference_date: reference_date,
            care_team_id: care_team_id,
            care_team: care_team,
            ms_scale: ms_scale
          )
        end

        def monthly_reference_dates(quadrimester, reference_date)
          range = Indicators::Quadrimester.range_for(quadrimester)
          dates = []
          cursor = range.begin.end_of_month
          while cursor <= range.end
            dates << cursor if range.cover?(cursor)
            cursor = cursor.next_month.end_of_month
          end
          dates = [ reference_date ] if dates.empty?
          dates
        end

        def team_indicator_rules(code, care_team_id: nil, care_team: nil, require_team: false)
          rules = RuleCatalog.dsl_v1_rules(indicator_codes: [ code ])
          if care_team_id.blank? && care_team.nil?
            raise Errors::TeamContextRequiredError, "care_team or care_team_id required for #{code.inspect}" if require_team

            return rules
          end

          team = care_team || CareTeam.find_by(id: care_team_id)
          raise Errors::UnknownCareTeamError, "care team not found: #{care_team_id.inspect}" unless team

          rules.select { |r| RuleCatalog.rule_applies_to_care_team?(r, team) }
        end

        def bp_rules_for(indicator_code, care_team_id: nil, care_team: nil)
          team_indicator_rules(
            indicator_code,
            care_team_id: care_team_id,
            care_team: care_team,
            require_team: true
          ).reject { |r| r.expression["skip_citizen_gaps"] || r.expression["skip_team_score"] }
        end

        def apply_linkage_sat_bonus(expression:, base_score:, citizens:, quadrimester:, reference_date:, care_team_id:, ms_scale:, care_team: nil)
          bonus_config = expression["linkage_sat_bonus"]
          return base_score unless bonus_config.is_a?(Hash)

          team = care_team || CareTeam.find_by(id: care_team_id)
          month_ends = monthly_reference_dates(quadrimester, reference_date)
          import_available = team && TeamSatisfactionSurveyScore
            .where(care_team_id: team.id, reference_month: month_ends.map { |d| d.beginning_of_month.to_date })
            .exists?
          return base_score if bonus_config["external_until_import"] && !import_available

          code = bonus_config.fetch("code")
          max_bonus = bonus_config.fetch("max_bonus", 1.0).to_f

          if import_available && team
            monthly_scores = month_ends.filter_map do |month_end|
              TeamSatisfactionSurveyScore.score_for_month(care_team: team, reference_date: month_end)
            end
            return base_score if monthly_scores.empty?

            sat_normalized = monthly_scores.sum / monthly_scores.size / 10.0
            bonus = (sat_normalized * max_bonus).round(2)
            max_total = ms_scale ? 10.0 : 100.0
            return [ base_score + bonus, max_total ].min.round(2)
          end

          resolved = child_indicator_team_score(
            code: code,
            citizens: citizens,
            quadrimester: quadrimester,
            reference_date: reference_date,
            care_team_id: care_team_id,
            care_team: care_team
          )
          return base_score unless resolved

          sat_score, sat_expression = resolved

          bonus = (sat_score / score_scale_divisor(sat_expression) * max_bonus).round(2)
          max_total = ms_scale ? 10.0 : 100.0
          [ base_score + bonus, max_total ].min.round(2)
        end

        def child_indicator_team_score(code:, citizens:, quadrimester:, reference_date:, care_team_id:, care_team:)
          team_rules = team_indicator_rules(
            code,
            care_team_id: care_team_id,
            care_team: care_team,
            require_team: true
          )
          scoring_rules = team_rules.reject { |r| r.expression["skip_team_score"] }
          child_rule = scoring_rules.find { |r| r.expression["team_score_mode"].present? } || scoring_rules.first
          return nil unless child_rule

          bp_rules = team_rules.reject { |r| r.expression["skip_citizen_gaps"] || r.expression["skip_team_score"] }
          expression = Indicators::TeamScoreExpression.resolve(
            indicator_code: code,
            rules: bp_rules,
            fallback_expression: child_rule.expression
          )
          score = team_score(
            expression: expression,
            citizens: citizens,
            quadrimester: quadrimester,
            reference_date: reference_date,
            care_team_id: care_team_id,
            care_team: care_team
          )
          [ score, expression ]
        end

        def score_scale_divisor(expression)
          expression["score_scale"].to_s == "ms_0_10" ? 10.0 : 100.0
        end
      end
    end
  end
end

# frozen_string_literal: true

module Indicators
  class DetectCitizenGaps < ApplicationCommand
    def initialize(citizen_id: nil, care_team_id: nil, indicator_codes: nil, reference_date: Date.current)
      @citizen_id = citizen_id
      @care_team_id = care_team_id
      @indicator_codes = indicator_codes
      @reference_date = reference_date
    end

    def call
      tenant = Cidadaobr::TenantContext.current_or_raise!
      quadrimester = Quadrimester.current(@reference_date)
      results = { gaps_opened: 0, gaps_resolved: 0, citizens_processed: 0 }

      citizens = citizens_for(tenant)
      rules = indicator_rules

      citizens.find_each do |citizen|
        results[:citizens_processed] += 1
        rules_for_citizen(citizen, rules).each do |rule|
          process_rule!(citizen: citizen, rule: rule, quadrimester: quadrimester, results: results)
        end
      end

      results
    end

    private

    def citizens_for(tenant)
      scope = Citizen.where(municipality_id: tenant.municipality_id)
      scope = scope.where(id: @citizen_id) if @citizen_id.present?
      scope = scope.where(care_team_id: @care_team_id) if @care_team_id.present?
      scope
    end

    def indicator_rules
      RuleCatalog.dsl_v1_rules(indicator_codes: @indicator_codes)
    end

    def rules_for_citizen(citizen, rules)
      care_team = citizen.care_team
      return [] if care_team.blank?

      rules.select { |rule| RuleCatalog.rule_applies_to_care_team?(rule, care_team) }
    end

    def process_rule!(citizen:, rule:, quadrimester:, results:)
      expression = rule.expression
      context = DslV1::Context.new(
        citizen: citizen,
        quadrimester: quadrimester,
        reference_date: @reference_date
      )
      evaluation = DslV1::Evaluator.evaluate(expression: expression, context: context)
      return unless evaluation.in_denominator

      good_practice_code = evaluation.good_practice_code
      if evaluation.meets_numerator
        results[:gaps_resolved] += resolve_gaps!(citizen: citizen, indicator_code: expression["indicator_code"], good_practice_code: good_practice_code)
      else
        results[:gaps_opened] += open_gap!(
          citizen: citizen,
          indicator_code: expression["indicator_code"],
          good_practice_code: good_practice_code
        )
      end
    end

    def open_gap!(citizen:, indicator_code:, good_practice_code:)
      existing = CitizenIndicatorGap.find_by(
        citizen_id: citizen.id,
        indicator_code: indicator_code,
        good_practice_code: good_practice_code,
        status: "open"
      )
      return 0 if existing

      gap = CitizenIndicatorGap.create!(
        municipality_id: citizen.municipality_id,
        citizen_id: citizen.id,
        care_team_id: citizen.care_team_id,
        indicator_code: indicator_code,
        good_practice_code: good_practice_code,
        status: "open",
        due_on: @reference_date
      )

      emit_gap_detected!(gap)
      1
    end

    def resolve_gaps!(citizen:, indicator_code:, good_practice_code:)
      scope = CitizenIndicatorGap.where(
        citizen_id: citizen.id,
        indicator_code: indicator_code,
        status: "open"
      )
      scope = scope.where(good_practice_code: good_practice_code) if good_practice_code.present?

      resolved = 0
      scope.find_each do |gap|
        gap.update!(status: "resolved")
        resolved += 1
      end
      resolved
    end

    def emit_gap_detected!(gap)
      RecordPlatformEvent.call(
        event_type: "indicator.gap.detected",
        aggregate_type: "CitizenIndicatorGap",
        aggregate_id: gap.id,
        payload: {
          gap_id: gap.id,
          citizen_id: gap.citizen_id,
          care_team_id: gap.care_team_id,
          indicator_code: gap.indicator_code,
          good_practice_code: gap.good_practice_code,
          status: gap.status
        },
        topic: OutboxPublisher::TOPIC_MAPPING.fetch("indicator.gap.detected"),
        care_team_id: gap.care_team_id
      )
    end
  end
end

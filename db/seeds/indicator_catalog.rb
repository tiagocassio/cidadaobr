# frozen_string_literal: true

METHODOLOGY_VERSION = "3493/2024" unless defined?(METHODOLOGY_VERSION)

def dsl_v1_expression(indicator_code:, denominator:, numerator:, good_practice_code: nil, team_score_mode: nil, skip_citizen_gaps: false, skip_team_score: false, linkage_components: nil, use_fixed_ms_weights: false, linkage_sat_bonus: nil)
  expression = {
    "version" => "dsl_v1",
    "indicator_code" => indicator_code,
    "methodology_version" => METHODOLOGY_VERSION,
    "denominator" => denominator,
    "numerator" => numerator
  }
  expression["good_practice_code"] = good_practice_code if good_practice_code.present?
  expression["team_score_mode"] = team_score_mode if team_score_mode.present?
  expression["skip_citizen_gaps"] = true if skip_citizen_gaps
  expression["skip_team_score"] = true if skip_team_score
  expression["use_fixed_ms_weights"] = true if use_fixed_ms_weights
  expression["linkage_sat_bonus"] = linkage_sat_bonus if linkage_sat_bonus.present?
  if linkage_components.present?
    expression["team_score_mode"] = "linkage_aggregate"
    expression["linkage_components"] = linkage_components
  end
  Indicators::MethodologyLoader.merge_into_expression(expression, code: indicator_code)
end

def indicator_display_name(code)
  I18n.t!("cidadaobr.indicators.catalog.#{code}.name")
end

def upsert_indicator!(code:, funding_component:, team_kind:, display_order:, expression:, rule_code: "default")
  catalog = IndicatorCatalog.find_or_initialize_by(code: code)
  catalog.assign_attributes(
    name: indicator_display_name(code),
    funding_component: funding_component,
    team_kind: team_kind,
    methodology_version: METHODOLOGY_VERSION,
    periodicity: "quarterly",
    display_order: display_order,
    active: true
  )
  catalog.save!

  IndicatorRule.find_or_initialize_by(indicator_catalog: catalog, rule_code: rule_code).tap do |rule|
    rule.rule_kind = "good_practice"
    rule.expression = expression
    rule.save!
  end

  catalog
end

upsert_indicator!(
  code: "CVAT",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 0,
  expression: dsl_v1_expression(
    indicator_code: "CVAT",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "citizens_on_team" },
    skip_citizen_gaps: true,
    use_fixed_ms_weights: true,
    linkage_components: [
      { "code" => "V_CAD", "weight" => 0.3 },
      { "code" => "V_ACOMP", "weight" => 0.7 }
    ],
    linkage_sat_bonus: { "code" => "V_SAT", "max_bonus" => 10.0 }
  )
)

upsert_indicator!(
  code: "V_CAD",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 1,
  expression: dsl_v1_expression(
    indicator_code: "V_CAD",
    good_practice_code: "V_CAD_COM",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "registration_complete" }
  )
)

v_cad_catalog = IndicatorCatalog.find_by!(code: "V_CAD")
IndicatorRule.find_or_initialize_by(indicator_catalog: v_cad_catalog, rule_code: "cad_atu").tap do |rule|
  rule.rule_kind = "good_practice"
  rule.expression = dsl_v1_expression(
    indicator_code: "V_CAD",
    good_practice_code: "V_CAD_ATU",
    skip_team_score: true,
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "registration_updated_mici", "within_months" => 24 }
  )
  rule.save!
end

IndicatorRule.find_or_initialize_by(indicator_catalog: v_cad_catalog, rule_code: "lim_cad").tap do |rule|
  rule.rule_kind = "good_practice"
  rule.expression = dsl_v1_expression(
    indicator_code: "V_CAD",
    good_practice_code: "V_LIM_CAD",
    skip_team_score: true,
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "registration_within_team_limit", "team_limit" => 3_500 }
  )
  rule.save!
end

upsert_indicator!(
  code: "V_ACOMP",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 2,
  expression: dsl_v1_expression(
    indicator_code: "V_ACOMP",
    good_practice_code: "V_ACOMP_12M",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "encounter_in_window", "within_months" => 12 }
  )
)

# Standalone linkage score on dashboard (encounter proxy MVP). Not in CVAT linkage_components until EPIC-05.
upsert_indicator!(
  code: "V_SAT",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 3,
  expression: dsl_v1_expression(
    indicator_code: "V_SAT",
    good_practice_code: "V_SAT",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "encounter_in_window", "within_months" => 6 }
  )
)

upsert_indicator!(
  code: "C1",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 10,
  expression: dsl_v1_expression(
    indicator_code: "C1",
    good_practice_code: "A",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "appointment_in_quadrimester", "statuses" => %w[scheduled checked_in completed] }
  )
)

upsert_indicator!(
  code: "C2",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 11,
  expression: dsl_v1_expression(
    indicator_code: "C2",
    good_practice_code: "A",
    denominator: { "type" => "citizens_age_lte", "max_age" => 2 },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAI],
      "within_months" => 12,
      "predicate" => { "type" => "present", "field_path" => "child_development" }
    }
  )
)

upsert_indicator!(
  code: "C3",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 12,
  expression: dsl_v1_expression(
    indicator_code: "C3",
    good_practice_code: "A",
    denominator: { "type" => "citizens_with_condition", "source" => "fci", "flag" => "pregnant" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAI],
      "within_months" => 6,
      "predicate" => { "type" => "present", "field_path" => "individual_attendances" }
    }
  )
)

upsert_indicator!(
  code: "C4",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 13,
  expression: dsl_v1_expression(
    indicator_code: "C4",
    good_practice_code: "F",
    denominator: { "type" => "citizens_with_condition", "source" => "fci", "flag" => "diabetes" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAI FP],
      "within_months" => 6,
      "predicate" => { "type" => "procedure_present", "code" => "0301040095" }
    }
  )
)

upsert_indicator!(
  code: "C5",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 14,
  expression: dsl_v1_expression(
    indicator_code: "C5",
    good_practice_code: "F",
    denominator: { "type" => "citizens_with_condition", "source" => "fci", "flag" => "hypertension" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAI FP],
      "within_months" => 6,
      "predicate" => { "type" => "present", "field_path" => "measurements" }
    }
  )
)

upsert_indicator!(
  code: "C6",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 15,
  expression: dsl_v1_expression(
    indicator_code: "C6",
    good_practice_code: "A",
    denominator: { "type" => "citizens_age_gte", "min_age" => 60 },
    numerator: { "type" => "encounter_in_window", "within_months" => 12 }
  )
)

upsert_indicator!(
  code: "C7",
  funding_component: "quality",
  team_kind: "esf",
  display_order: 16,
  expression: dsl_v1_expression(
    indicator_code: "C7",
    good_practice_code: "A",
    denominator: { "type" => "citizens_sex_female" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAI FP],
      "within_months" => 36,
      "predicate" => { "type" => "procedure_present", "code" => "0201020074" }
    }
  )
)

upsert_indicator!(
  code: "B1",
  funding_component: "quality",
  team_kind: "esb",
  display_order: 17,
  expression: dsl_v1_expression(
    indicator_code: "B1",
    good_practice_code: "B1",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAO],
      "within_months" => 12,
      "predicate" => { "type" => "dental_first_consult" }
    }
  )
)

upsert_indicator!(
  code: "B2",
  funding_component: "quality",
  team_kind: "esb",
  display_order: 18,
  expression: dsl_v1_expression(
    indicator_code: "B2",
    good_practice_code: "B2",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAO],
      "within_months" => 12,
      "predicate" => { "type" => "dental_treatment_completed" }
    }
  )
)

upsert_indicator!(
  code: "B3",
  funding_component: "quality",
  team_kind: "esb",
  display_order: 19,
  expression: dsl_v1_expression(
    indicator_code: "B3",
    good_practice_code: "B3",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "encounter_in_window", "within_months" => 3 },
    team_score_mode: "procedure_ratio",
    skip_citizen_gaps: true
  )
)

upsert_indicator!(
  code: "B4",
  funding_component: "quality",
  team_kind: "esb",
  display_order: 20,
  expression: dsl_v1_expression(
    indicator_code: "B4",
    good_practice_code: "B4",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAC FAO],
      "within_months" => 12,
      "predicate" => { "type" => "supervised_brushing" }
    }
  )
)

upsert_indicator!(
  code: "B5",
  funding_component: "quality",
  team_kind: "esb",
  display_order: 21,
  expression: dsl_v1_expression(
    indicator_code: "B5",
    good_practice_code: "B5",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAO],
      "within_months" => 12,
      "predicate" => { "type" => "preventive_procedure" }
    }
  )
)

upsert_indicator!(
  code: "B6",
  funding_component: "quality",
  team_kind: "esb",
  display_order: 22,
  expression: dsl_v1_expression(
    indicator_code: "B6",
    good_practice_code: "B6",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAO],
      "within_months" => 12,
      "predicate" => { "type" => "tra_procedure" }
    }
  )
)

upsert_indicator!(
  code: "M1",
  funding_component: "quality",
  team_kind: "emulti",
  display_order: 23,
  expression: dsl_v1_expression(
    indicator_code: "M1",
    good_practice_code: "M1",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "emulti_encounter_count",
      "record_types" => %w[FAC FAI FAO],
      "within_months" => 3,
      "minimum_count" => 1
    }
  )
)

upsert_indicator!(
  code: "M2",
  funding_component: "quality",
  team_kind: "emulti",
  display_order: 24,
  expression: dsl_v1_expression(
    indicator_code: "M2",
    good_practice_code: "M2",
    denominator: { "type" => "citizens_on_team" },
    numerator: {
      "type" => "clinical_predicate",
      "record_types" => %w[FAC FCC],
      "within_months" => 12,
      "predicate" => { "type" => "interprofessional_action" }
    }
  )
)

deactivated_count = IndicatorCatalog.where.not(code: IndicatorCatalog::PORTARIA_3493_CODES).where(active: true).update_all(
  active: false,
  updated_at: Time.current
)

portaria_rule_count = IndicatorRule.joins(:indicator_catalog).merge(IndicatorCatalog.active_portaria).count
puts "  Indicator catalog: #{IndicatorCatalog.active_portaria.count} entries, #{portaria_rule_count} rules"
puts "  Deactivated #{deactivated_count} non-Portaria catalog entries" if deactivated_count.positive?

# frozen_string_literal: true

METHODOLOGY_VERSION = "3493/2024" unless defined?(METHODOLOGY_VERSION)

def stub_expression(code)
  {
    "version" => "dsl_v1_stub",
    "indicator_code" => code,
    "methodology_version" => METHODOLOGY_VERSION,
    "status" => "seed_placeholder"
  }
end

def dsl_v1_expression(indicator_code:, good_practice_code:, denominator:, numerator:)
  {
    "version" => "dsl_v1",
    "indicator_code" => indicator_code,
    "good_practice_code" => good_practice_code,
    "methodology_version" => METHODOLOGY_VERSION,
    "denominator" => denominator,
    "numerator" => numerator
  }
end

def indicator_display_name(code)
  I18n.t!("cidadaobr.indicators.catalog.#{code}.name")
end

def upsert_indicator!(code:, funding_component:, team_kind:, display_order:, rule_code: "default", expression: nil)
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
    rule.expression = expression || stub_expression(code)
    rule.save!
  end

  catalog
end

upsert_indicator!(
  code: "CVAT",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 0
)

upsert_indicator!(
  code: "V_CAD",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 1,
  expression: dsl_v1_expression(
    indicator_code: "V_CAD",
    good_practice_code: "CAD",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "registration_complete" }
  )
)

upsert_indicator!(
  code: "V_ACOMP",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 2,
  expression: dsl_v1_expression(
    indicator_code: "V_ACOMP",
    good_practice_code: "ACOMP",
    denominator: { "type" => "citizens_on_team" },
    numerator: { "type" => "encounter_in_window", "within_months" => 12 }
  )
)

upsert_indicator!(
  code: "V_SAT",
  funding_component: "linkage",
  team_kind: "esf",
  display_order: 3
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
  display_order: 11
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

[
  [ "C8", "quality", "esb", 17 ],
  [ "C9", "quality", "esb", 18 ],
  [ "C10", "quality", "esb", 19 ],
  [ "C11", "quality", "esb", 20 ],
  [ "C12", "quality", "esb", 21 ],
  [ "C13", "quality", "esb", 22 ],
  [ "C14", "quality", "emulti", 23 ],
  [ "C15", "quality", "emulti", 24 ]
].each do |code, component, team_kind, order|
  upsert_indicator!(code: code, funding_component: component, team_kind: team_kind, display_order: order)
end

puts "  Indicator catalog: #{IndicatorCatalog.count} entries, #{IndicatorRule.count} rules"

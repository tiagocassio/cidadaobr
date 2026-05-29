# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Indicator catalog seed" do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "loads only Portaria 3.493/2024 indicator codes" do
    expect(IndicatorCatalog.find_by!(code: "CVAT").name).to include("Avaliação Territorial")
    expect(IndicatorCatalog.portaria.pluck(:code)).to match_array(IndicatorCatalog::PORTARIA_3493_CODES)
    expect(IndicatorCatalog.active_portaria.count).to eq(IndicatorCatalog::PORTARIA_3493_CODES.size)

    portaria_rule_count = IndicatorRule.joins(:indicator_catalog).merge(IndicatorCatalog.active_portaria).count
    expect(portaria_rule_count).to eq(IndicatorCatalog.active_portaria.count)
  end

  it "seeds only official Portaria good_practice_code values in dsl_v1 expressions" do
    portaria_rules = IndicatorRule.joins(:indicator_catalog).merge(IndicatorCatalog.active_portaria)
    codes = portaria_rules.pluck(:expression).filter_map { |expression| expression["good_practice_code"] }.uniq
    expect(codes).to all(satisfy { |code| Indicators::Portaria3493.known_good_practice_code?(code) })
    expect(codes).not_to include("CAD", "ACOMP", "SAT", "VAC")
  end

  it "deactivates legacy catalog codes outside Portaria 3.493/2024" do
    legacy = IndicatorCatalog.new(
      code: "C8",
      name: "Legacy indicator",
      funding_component: "quality",
      methodology_version: "3493/2024",
      periodicity: "quarterly",
      active: true
    )
    legacy.save(validate: false)

    load Rails.root.join("db/seeds/indicator_catalog.rb")

    expect(IndicatorCatalog.find_by!(code: "C8").active).to be(false)
  end

  it "skips citizen gaps for aggregate CVAT" do
    cvat = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "CVAT" }).expression
    expect(cvat["skip_citizen_gaps"]).to be(true)
    expect(cvat["good_practice_code"]).to be_nil
    expect(cvat["team_score_mode"]).to eq("linkage_aggregate")
    expect(cvat["linkage_components"]).to contain_exactly(
      { "code" => "V_CAD", "weight" => 0.3 },
      { "code" => "V_ACOMP", "weight" => 0.7 }
    )
  end

  it "tags quality indicators with funding_component quality" do
    expect(IndicatorCatalog.find_by!(code: "C4").funding_component).to eq("quality")
    expect(IndicatorCatalog.find_by!(code: "B1").funding_component).to eq("quality")
    expect(IndicatorCatalog.find_by!(code: "V_CAD").funding_component).to eq("linkage")
  end

  it "seeds dsl_v1 expressions for C4, C5 and V_CAD" do
    expect(IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C4" }).expression["version"]).to eq("dsl_v1")
    expect(IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C5" }).expression["denominator"]["flag"]).to eq("hypertension")
    expect(IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "V_CAD" }).expression["numerator"]["type"]).to eq("registration_complete")
  end

  it "seeds dsl_v1 for B1 and M2 with SAPS source_ref" do
    b1 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "B1" }).expression
    m2 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "M2" }).expression

    expect(b1["version"]).to eq("dsl_v1")
    expect(b1["source_ref"]).to include("equipe-de-saude-bucal")
    expect(m2["version"]).to eq("dsl_v1")
    expect(m2["source_ref"]).to include("equipes-multiprofissionais-emulti")
  end

  it "stores English field_path aliases in dsl_v1 expressions" do
    c3 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C3" }).expression
    c5 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C5" }).expression

    expect(c3.dig("numerator", "predicate", "field_path")).to eq("individual_attendances")
    expect(c5.dig("numerator", "predicate", "field_path")).to eq("measurements")
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Indicator catalog seed" do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "loads only Portaria 3.493/2024 indicator codes from methodology packs" do
    expect(IndicatorCatalog.find_by!(code: "CVAT").name).to include("Avaliação Territorial")
    expect(IndicatorCatalog.portaria.pluck(:code)).to match_array(IndicatorCatalog::PORTARIA_3493_CODES)
    expect(IndicatorCatalog.active_portaria.count).to eq(IndicatorCatalog::PORTARIA_3493_CODES.size)
  end

  it "seeds multiple BP rules per quality indicator from packs" do
    portaria_rule_count = IndicatorRule.joins(:indicator_catalog).where(indicator_catalog: Indicators::RuleCatalog.active_portaria_attributes).count
    expect(portaria_rule_count).to be >= 40
    expect(IndicatorRule.joins(:indicator_catalog).where(indicator_catalog: { code: "C4" }).count).to eq(6)
    expect(IndicatorRule.joins(:indicator_catalog).where(indicator_catalog: { code: "C3" }).count).to eq(11)
  end

  it "seeds only official Portaria good_practice_code values in dsl_v1 expressions" do
    portaria_rules = IndicatorRule.joins(:indicator_catalog).where(indicator_catalog: Indicators::RuleCatalog.active_portaria_attributes)
    codes = portaria_rules.pluck(:expression).filter_map { |expression| expression["good_practice_code"] }.uniq
    expect(codes).to all(satisfy { |code| Indicators::Portaria3493.known_good_practice_code?(code) })
    expect(codes).not_to include("CAD", "ACOMP", "SAT", "VAC")
  end

  it "preserves custom catalog codes outside the official Portaria code list" do
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

    expect(IndicatorCatalog.find_by!(code: "C8").active).to be(true)
  end

  it "deactivates official Portaria codes removed from methodology packs" do
    load Rails.root.join("db/seeds/indicator_catalog.rb")
    expect(IndicatorCatalog.find_by!(code: "M2").active).to be(true)

    packs_without_m2 = Indicators::MethodologyPackDefinitions.all.reject { |pack| pack.dig("catalog", "code") == "M2" }
    allow(Indicators::MethodologyPackDefinitions).to receive(:all).and_return(packs_without_m2)

    load Rails.root.join("db/seeds/indicator_catalog.rb")

    expect(IndicatorCatalog.find_by!(code: "M2").active).to be(false)
  end

  it "removes stale indicator rules no longer present in methodology packs" do
    catalog = IndicatorCatalog.find_by!(code: "V_CAD")
    IndicatorRule.create!(
      indicator_catalog: catalog,
      rule_code: "obsolete_rule",
      rule_kind: "good_practice",
      expression: { "version" => "dsl_v1", "denominator" => {}, "numerator" => {} }
    )

    load Rails.root.join("db/seeds/indicator_catalog.rb")

    expect(IndicatorRule.find_by(indicator_catalog: catalog, rule_code: "obsolete_rule")).to be_nil
  end

  it "skips citizen gaps for aggregate CVAT with MS 0–10 scale" do
    cvat = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "CVAT" }).expression
    expect(cvat["skip_citizen_gaps"]).to be(true)
    expect(cvat["good_practice_code"]).to be_nil
    expect(cvat["team_score_mode"]).to eq("linkage_aggregate")
    expect(cvat["score_scale"]).to eq("ms_0_10")
    expect(cvat["linkage_components"]).to contain_exactly(
      { "code" => "V_CAD", "weight" => 3.0 },
      { "code" => "V_ACOMP", "weight" => 7.0 }
    )
  end

  it "tags quality indicators with funding_component quality" do
    expect(IndicatorCatalog.find_by!(code: "C4").funding_component).to eq("quality")
    expect(IndicatorCatalog.find_by!(code: "B1").funding_component).to eq("quality")
    expect(IndicatorCatalog.find_by!(code: "V_CAD").funding_component).to eq("linkage")
  end

  it "seeds dsl_v1 MICI/MICDT for V_CAD and hypertension flag for C5" do
    v_cad = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "V_CAD" }, rule_code: "default").expression
    c5 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C5" }, rule_code: "A").expression

    expect(v_cad["version"]).to eq("dsl_v1")
    expect(v_cad["numerator"]["type"]).to eq("mici_micdt_complete")
    cad_atu = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "V_CAD" }, rule_code: "cad_atu").expression
    expect(cad_atu["skip_team_score"]).to be(true)
    expect(c5["denominator"]["flag"]).to eq("hypertension")
  end

  it "seeds dsl_v1 for B1 and M2 with SAPS source_ref" do
    b1 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "B1" }).expression
    m2 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "M2" }).expression

    expect(b1["version"]).to eq("dsl_v1")
    expect(b1["source_ref"]).to include("equipe-de-saude-bucal")
    expect(m2["version"]).to eq("dsl_v1")
    expect(m2["source_ref"]).to include("equipes-multiprofissionais-emulti")
  end

  it "exports pack JSON files via catalog:export_packs rake task" do
    Indicators::MethodologyPackLoader.ensure_pack_json_export!
    packs_dir = Rails.root.join("lib/indicators/methodology/3493-2024/packs")
    expect(packs_dir).to be_directory
    expect(packs_dir.glob("*.json").count).to be >= 40
  end

  it "stores external_until_import on CVAT SAT bonus config" do
    cvat = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "CVAT" }).expression
    expect(cvat.dig("linkage_sat_bonus", "external_until_import")).to be(true)
  end
end

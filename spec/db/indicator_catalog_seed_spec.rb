# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Indicator catalog seed" do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "loads CVAT, C1–C7, B1–B6 and M1–M2 indicators" do
    expect(IndicatorCatalog.find_by!(code: "CVAT").name).to include("Avaliação Territorial")
    expect(IndicatorCatalog.where(code: (1..7).map { |n| "C#{n}" }).count).to eq(7)
    expect(IndicatorCatalog.where(code: %w[B1 B2 B3 B4 B5 B6]).count).to eq(6)
    expect(IndicatorCatalog.where(code: %w[M1 M2]).count).to eq(2)
    expect(IndicatorRule.count).to eq(IndicatorCatalog.count)
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

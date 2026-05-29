# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Indicator catalog seed" do
  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "loads CVAT and C1–C15 indicators" do
    expect(IndicatorCatalog.find_by!(code: "CVAT").name).to include("Avaliação Territorial")
    expect(IndicatorCatalog.where(code: (1..15).map { |n| "C#{n}" }).count).to eq(15)
    expect(IndicatorRule.count).to eq(IndicatorCatalog.count)
  end

  it "tags quality indicators with funding_component quality" do
    expect(IndicatorCatalog.find_by!(code: "C4").funding_component).to eq("quality")
    expect(IndicatorCatalog.find_by!(code: "V_CAD").funding_component).to eq("linkage")
  end

  it "seeds dsl_v1 expressions for C4, C5 and V_CAD" do
    expect(IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C4" }).expression["version"]).to eq("dsl_v1")
    expect(IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C5" }).expression["denominator"]["flag"]).to eq("hypertension")
    expect(IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "V_CAD" }).expression["numerator"]["type"]).to eq("registration_complete")
  end

  it "stores English field_path aliases in dsl_v1 expressions" do
    c3 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C3" }).expression
    c5 = IndicatorRule.joins(:indicator_catalog).find_by!(indicator_catalog: { code: "C5" }).expression

    expect(c3.dig("numerator", "predicate", "field_path")).to eq("individual_attendances")
    expect(c5.dig("numerator", "predicate", "field_path")).to eq("measurements")
  end
end

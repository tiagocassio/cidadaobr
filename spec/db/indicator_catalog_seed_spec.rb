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
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::Scoring do
  it "loads repasse coefficients from config when present" do
    expect(described_class.repasse_coefficients.dig("esf", "linkage")).to eq(5_000.0)
  end

  it "projects transfer from catalog entry and score" do
    catalog = IndicatorCatalog.new(code: "V_CAD", funding_component: "linkage", team_kind: "esf")
    amount = described_class.projected_transfer(50.0, catalog_entry: catalog)

    expect(amount).to eq(2_500.0)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::Scoring do
  describe ".projected_transfer" do
    def catalog_entry(team_kind:, funding_component:)
      IndicatorCatalog.new(team_kind: team_kind, funding_component: funding_component)
    end

    it "weights by funding component and team kind" do
      amount = described_class.projected_transfer(80.0, catalog_entry: catalog_entry(team_kind: "esf", funding_component: "quality"))
      expect(amount).to eq(5_600.0)
    end

    it "returns zero when component has no base" do
      entry = catalog_entry(team_kind: "esb", funding_component: "linkage")
      expect(described_class.projected_transfer(90.0, catalog_entry: entry)).to eq(0.0)
    end
  end
end

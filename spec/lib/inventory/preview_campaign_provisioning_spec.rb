# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::PreviewCampaignProvisioning do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product) { create(:immunobiologic_product, municipality: municipality) }
  let(:other_product) { create(:immunobiologic_product, municipality: municipality, code: "OTHER") }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "returns zero available doses when product id is missing" do
    with_tenant(membership) do
      create(
        :immunobiologic_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: product,
        quantity_on_hand: 100
      )
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)

      available = described_class.send(
        :available_for_line,
        campaign: campaign,
        line: { "unit" => "dose" }
      )

      expect(available).to eq(0)
    end
  end

  it "scopes dose availability to the requested product" do
    with_tenant(membership) do
      create(
        :immunobiologic_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: product,
        quantity_on_hand: 100
      )
      create(
        :immunobiologic_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: other_product,
        quantity_on_hand: 50
      )
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)

      available = described_class.send(
        :available_for_line,
        campaign: campaign,
        line: { "unit" => "dose", "immunobiologic_product_id" => product.id }
      )

      expect(available).to eq(100)
    end
  end

  it "subtracts committed syringes for syringe supply lines" do
    with_tenant(membership) do
      syringe = SupplyItem.create!(municipality: municipality, code: "SYRINGE-1ML", name: "Seringa", unit: "unit")
      StockBalance.create!(
        municipality: municipality,
        health_facility: facility,
        supply_item: syringe,
        quantity: 500
      )
      VaccinationCampaign.create!(
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: product,
        name: "Campanha vacina",
        campaign_kind: "human_immunization",
        starts_on: Date.current,
        ends_on: Date.current + 6.days,
        target_doses: 400,
        room_capacity_per_day: 50,
        status: "provisioning_approved"
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunologic_product_id" => product.id }
      )

      available = described_class.send(
        :available_for_line,
        campaign: campaign,
        line: { "unit" => "unit", "supply_item_code" => "SYRINGE-1ML", "key" => "SYRINGE-1ML" }
      )

      expect(available).to eq(100)
    end
  end
end

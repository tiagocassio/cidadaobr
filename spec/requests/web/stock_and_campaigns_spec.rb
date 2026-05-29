# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web stock and campaigns", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:product) { create(:immunobiologic_product, municipality: municipality) }

  before { sign_in_web(user: membership.user, membership: membership) }

  describe "immunobiologic products" do
    it "lists and creates products" do
      get web_stock_immunobiologic_products_path
      expect(response).to have_http_status(:ok)

      expect {
        post web_stock_immunobiologic_products_path, params: {
          immunobiologic_product: { code: "HEPB", name: "Hepatite B", target_species: "human", active: true }
        }
      }.to change { with_tenant(membership) { ImmunobiologicProduct.count } }.by(1)

      expect(response).to redirect_to(web_stock_immunobiologic_products_path)
    end
  end

  describe "immunobiologic lots" do
    it "registers a lot" do
      expect {
        post web_stock_immunobiologic_lots_path, params: {
          immunobiologic_lot: {
            health_facility_id: facility.id,
            immunobiologic_product_id: product.id,
            lot_number: "LOT-1",
            expires_on: 1.year.from_now.to_date,
            quantity_on_hand: 100
          }
        }
      }.to change { with_tenant(membership) { ImmunobiologicLot.count } }.by(1)

      expect(response).to redirect_to(web_stock_immunobiologic_lots_path)
    end
  end

  describe "vaccination campaigns" do
    it "creates a campaign and runs provisioning" do
      with_tenant(membership) do
        create(
          :immunobiologic_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiologic_product: product,
          quantity_on_hand: 500
        )
      end

      expect {
        post web_campaigns_vaccination_campaigns_path, params: {
          vaccination_campaign: {
            name: "Influenza 60+",
            health_facility_id: facility.id,
            immunobiologic_product_id: product.id,
            campaign_kind: "human_immunization",
            starts_on: Date.current,
            ends_on: Date.current + 6.days,
            target_doses: 200,
            room_capacity_per_day: 50,
            target_audience_definition: { min_age: 60 }
          }
        }
      }.to change { with_tenant(membership) { VaccinationCampaign.count } }.by(1)

      campaign = with_tenant(membership) { VaccinationCampaign.order(:created_at).last }
      expect(response).to redirect_to(web_campaigns_vaccination_campaign_path(campaign))
      expect(with_tenant(membership) { campaign.supply_provisioning.status }).to eq("approved")
    end
  end
end

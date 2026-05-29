# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web stock and campaigns", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:other_facility) { create(:health_facility, municipality: municipality, cnes: "2999999", name: "UBS B") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:facility_membership) do
    create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility",
      role_code: "facility_manager"
    )
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

    it "ignores a foreign facility id and registers the lot in the user facility" do
      sign_in_web(user: facility_membership.user, membership: facility_membership)

      expect {
        post web_stock_immunobiologic_lots_path, params: {
          immunobiologic_lot: {
            health_facility_id: other_facility.id,
            immunobiologic_product_id: product.id,
            lot_number: "LOT-X",
            expires_on: 1.year.from_now.to_date,
            quantity_on_hand: 100
          }
        }
      }.to change { with_tenant(facility_membership) { ImmunobiologicLot.count } }.by(1)

      lot = with_tenant(facility_membership) { ImmunobiologicLot.order(:created_at).last }
      expect(lot.health_facility_id).to eq(facility.id)
      expect(response).to redirect_to(web_stock_immunobiologic_lots_path)
    end

    it "rejects an unknown facility id for municipality users" do
      expect {
        post web_stock_immunobiologic_lots_path, params: {
          immunobiologic_lot: {
            health_facility_id: SecureRandom.uuid,
            immunobiologic_product_id: product.id,
            lot_number: "LOT-REJECT",
            expires_on: 1.year.from_now.to_date,
            quantity_on_hand: 100
          }
        }
      }.not_to change { with_tenant(membership) { ImmunobiologicLot.count } }

      expect(response).to have_http_status(:unprocessable_entity)
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

    it "blocks publish without campaign targets" do
      campaign = nil
      with_tenant(membership) do
        create(
          :immunobiologic_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiologic_product: product,
          quantity_on_hand: 500
        )
        campaign = create(
          :vaccination_campaign,
          municipality: municipality,
          health_facility: facility,
          immunobiologic_product: product,
          target_doses: 100,
          room_capacity_per_day: 50,
          status: "provisioning_approved"
        )
        Inventory::ProvisioningValidator.persist!(campaign: campaign)
      end

      post publish_web_campaigns_vaccination_campaign_path(campaign)

      expect(response).to redirect_to(web_campaigns_vaccination_campaign_path(campaign))
      expect(with_tenant(membership) { campaign.reload.status }).not_to eq("active")
    end
  end

  describe "home visit campaigns" do
    it "does not persist provisioning rollup on preview GET" do
      campaign = with_tenant(membership) do
        create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      end

      expect {
        get preview_provisioning_web_campaigns_home_visit_campaign_path(campaign)
      }.not_to change { with_tenant(membership) { HomeVisitCampaignProvisioning.count } }

      expect(response).to have_http_status(:ok)
    end

    it "persists provisioning rollup on calculate POST" do
      campaign = with_tenant(membership) do
        create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      end

      expect {
        post calculate_provisioning_web_campaigns_home_visit_campaign_path(campaign)
      }.to change { with_tenant(membership) { HomeVisitCampaignProvisioning.count } }.by(1)

      expect(response).to redirect_to(preview_provisioning_web_campaigns_home_visit_campaign_path(campaign))
    end

    it "publishes generated routes for the field API" do
      campaign = nil
      route = nil
      with_tenant(membership) do
        campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
        team = create(:care_team, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: campaign, route_date: Date.current)
        route = campaign.visit_routes.first
      end

      post publish_routes_web_campaigns_home_visit_campaign_path(campaign)

      expect(response).to redirect_to(web_campaigns_home_visit_campaign_path(campaign))
      expect(with_tenant(membership) { route.reload.status }).to eq("published")
      expect(with_tenant(membership) { campaign.reload.status }).to eq("scheduled")
    end

    it "blocks publish when provisioning is blocked" do
      campaign = nil
      route = nil
      with_tenant(membership) do
        product = create(:immunobiologic_product, municipality: municipality)
        campaign = create(
          :home_visit_campaign,
          municipality: municipality,
          health_facility: facility,
          status: "routes_generated",
          target_audience_definition: { "immunologic_product_id" => product.id }
        )
        team = create(:care_team, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(
          :campaign_target,
          municipality: municipality,
          health_facility: facility,
          campaign: campaign,
          citizen: citizen
        )
        Routing::Commands::GenerateVisitRoutes.call(campaign: campaign, route_date: Date.current)
        route = campaign.visit_routes.first
        expect(campaign.home_visit_campaign_provisioning.status).to eq("blocked")
      end

      post publish_routes_web_campaigns_home_visit_campaign_path(campaign)

      expect(response).to redirect_to(web_campaigns_home_visit_campaign_path(campaign))
      expect(flash[:alert]).to be_present
      expect(with_tenant(membership) { route.reload.status }).to eq("draft")
    end

    it "regenerates routes after clearing the current date" do
      campaign = nil
      with_tenant(membership) do
        campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
        team = create(:care_team, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: campaign, route_date: Date.current)
      end

      post clear_routes_web_campaigns_home_visit_campaign_path(campaign)
      expect(with_tenant(membership) { campaign.visit_routes.count }).to eq(0)

      post generate_routes_web_campaigns_home_visit_campaign_path(campaign)
      expect(with_tenant(membership) { campaign.visit_routes.count }).to eq(1)
    end
  end
end

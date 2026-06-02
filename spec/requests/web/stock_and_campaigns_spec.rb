# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web stock and campaigns", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) do
    create(
      :health_facility,
      municipality: municipality,
      location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
    )
  end
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
  let(:product) { create(:immunobiological_product, municipality: municipality) }

  before { sign_in_web(user: membership.user, membership: membership) }

  describe "immunobiological products" do
    it "lists and creates products" do
      get web_stock_immunobiological_products_path
      expect(response).to have_http_status(:ok)

      expect {
        post web_stock_immunobiological_products_path, params: {
          immunobiological_product: { code: "HEPB", name: "Hepatite B", target_species: "human", active: true }
        }
      }.to change { with_tenant(membership) { ImmunobiologicalProduct.count } }.by(1)

      expect(response).to redirect_to(web_stock_immunobiological_products_path)
    end
  end

  describe "supply items" do
    it "lists and creates a simple supply item" do
      get web_stock_supply_items_path
      expect(response).to have_http_status(:ok)

      expect {
        post web_stock_supply_items_path, params: {
          supply_item: {
            category: "syringe",
            name: "Seringa 1 ml",
            unit: "unit",
            kind: "simple",
            description: "Vacinação domiciliar",
            active: true
          }
        }
      }.to change { with_tenant(membership) { SupplyItem.count } }.by(1)

      expect(response).to redirect_to(web_stock_supply_items_path)
    end

    it "creates a composite supply item with components" do
      syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
      lancet = create(:supply_item, municipality: municipality, name: "Lanceta", category: "lancet")

      expect {
        post web_stock_supply_items_path, params: {
          supply_item: {
            category: "visit_kit",
            name: "Kit visita",
            unit: "kit",
            kind: "composite",
            description: "Kit por parada",
            active: true,
            components: [
              { component_item_id: syringe.id, quantity_per_unit: 1 },
              { component_item_id: lancet.id, quantity_per_unit: 2 }
            ]
          }
        }
      }.to change { with_tenant(membership) { SupplyItem.where(kind: "composite").count } }.by(1)
        .and change { with_tenant(membership) { SupplyItemComponent.count } }.by(2)

      kit = with_tenant(membership) { SupplyItem.find_by!(name: "Kit visita") }
      expect(with_tenant(membership) { kit.supply_item_components.count }).to eq(2)
      expect(response).to redirect_to(web_stock_supply_items_path)
    end

    it "re-renders new when composite create has invalid components" do
      syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")

      expect {
        post web_stock_supply_items_path, params: {
          supply_item: {
            category: "visit_kit",
            name: "Kit inválido",
            unit: "kit",
            kind: "composite",
            description: "Kit",
            active: true,
            components: [
              { component_item_id: syringe.id, quantity_per_unit: 1 },
              { component_item_id: syringe.id, quantity_per_unit: 2 }
            ]
          }
        }
      }.not_to change { with_tenant(membership) { SupplyItem.where(name: "Kit inválido").count } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('action="/web/stock/supply_items"')
      expect(response.body).not_to include('action="/web/stock/supply_items/')
    end

    it "includes inactive linked components in the edit select" do
      inactive_syringe = create(
        :supply_item,
        municipality: municipality,
        name: "Seringa inativa",
        category: "syringe",
        active: false
      )
      kit = with_tenant(membership) do
        item = SupplyItem.create!(
          municipality: municipality,
          category: "visit_kit",
          name: "Kit com inativo",
          unit: "kit",
          kind: "composite",
          description: "Kit"
        )
        SupplyItemComponent.create!(
          municipality: municipality,
          composite_item: item,
          component_item: inactive_syringe,
          quantity_per_unit: 1
        )
        item
      end

      get edit_web_stock_supply_item_path(kit)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Seringa inativa")
    end

    it "updates a composite supply item replacing components" do
      syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
      lancet = create(:supply_item, municipality: municipality, name: "Lanceta", category: "lancet")
      kit = with_tenant(membership) do
        item = SupplyItem.create!(
          municipality: municipality,
          category: "visit_kit",
          name: "Kit antigo",
          unit: "kit",
          kind: "composite",
          description: "Kit"
        )
        SupplyItemComponent.create!(
          municipality: municipality,
          composite_item: item,
          component_item: syringe,
          quantity_per_unit: 1
        )
        item
      end

      patch web_stock_supply_item_path(kit), params: {
        supply_item: {
          category: "visit_kit",
          name: "Kit atualizado",
          unit: "kit",
          kind: "composite",
          description: "Kit revisado",
          active: true,
          components: [
            { component_item_id: lancet.id, quantity_per_unit: 3 }
          ]
        }
      }

      expect(response).to redirect_to(web_stock_supply_items_path)
      with_tenant(membership) do
        kit.reload
        expect(kit.name).to eq("Kit atualizado")
        expect(kit.supply_item_components.count).to eq(1)
        expect(kit.supply_item_components.first.component_item_id).to eq(lancet.id)
        expect(kit.supply_item_components.first.quantity_per_unit).to eq(3)
      end
    end

    it "re-renders edit when composite update has invalid components" do
      syringe = create(:supply_item, municipality: municipality, name: "Seringa", category: "syringe")
      kit = with_tenant(membership) do
        item = SupplyItem.create!(
          municipality: municipality,
          category: "visit_kit",
          name: "Kit antigo",
          unit: "kit",
          kind: "composite",
          description: "Kit"
        )
        SupplyItemComponent.create!(
          municipality: municipality,
          composite_item: item,
          component_item: syringe,
          quantity_per_unit: 1
        )
        item
      end

      patch web_stock_supply_item_path(kit), params: {
        supply_item: {
          category: "visit_kit",
          name: "Kit alterado",
          unit: "kit",
          kind: "composite",
          description: "Kit",
          active: true,
          components: [
            { component_item_id: syringe.id, quantity_per_unit: 1 },
            { component_item_id: syringe.id, quantity_per_unit: 2 }
          ]
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      with_tenant(membership) do
        kit.reload
        expect(kit.name).to eq("Kit antigo")
        expect(kit.supply_item_components.count).to eq(1)
      end
      expect(response.body).to include("Kit alterado")
    end
  end

  describe "immunobiological lots" do
    it "registers a lot" do
      expect {
        post web_stock_immunobiological_lots_path, params: {
          immunobiological_lot: {
            health_facility_id: facility.id,
            immunobiological_product_id: product.id,
            lot_number: "LOT-1",
            expires_on: 1.year.from_now.to_date,
            quantity_on_hand: 100
          }
        }
      }.to change { with_tenant(membership) { ImmunobiologicalLot.count } }.by(1)

      expect(response).to redirect_to(web_stock_immunobiological_lots_path)
    end

    it "ignores a foreign facility id and registers the lot in the user facility" do
      sign_in_web(user: facility_membership.user, membership: facility_membership)

      expect {
        post web_stock_immunobiological_lots_path, params: {
          immunobiological_lot: {
            health_facility_id: other_facility.id,
            immunobiological_product_id: product.id,
            lot_number: "LOT-X",
            expires_on: 1.year.from_now.to_date,
            quantity_on_hand: 100
          }
        }
      }.to change { with_tenant(facility_membership) { ImmunobiologicalLot.count } }.by(1)

      lot = with_tenant(facility_membership) { ImmunobiologicalLot.order(:created_at).last }
      expect(lot.health_facility_id).to eq(facility.id)
      expect(response).to redirect_to(web_stock_immunobiological_lots_path)
    end

    it "rejects an unknown facility id for municipality users" do
      expect {
        post web_stock_immunobiological_lots_path, params: {
          immunobiological_lot: {
            health_facility_id: SecureRandom.uuid,
            immunobiological_product_id: product.id,
            lot_number: "LOT-REJECT",
            expires_on: 1.year.from_now.to_date,
            quantity_on_hand: 100
          }
        }
      }.not_to change { with_tenant(membership) { ImmunobiologicalLot.count } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "vaccination campaigns" do
    it "creates a campaign via wizard step 1 and redirects to audience step" do
      with_tenant(membership) do
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 500
        )
      end

      expect {
        post web_campaigns_vaccination_campaigns_path, params: {
          vaccination_campaign: {
            name: "Influenza 60+",
            health_facility_id: facility.id,
            immunobiological_product_id: product.id,
            campaign_kind: "human_immunization",
            starts_on: Date.current,
            ends_on: Date.current + 6.days,
            room_capacity_per_day: 50
          }
        }
      }.to change { with_tenant(membership) { VaccinationCampaign.count } }.by(1)

      campaign = with_tenant(membership) { VaccinationCampaign.order(:created_at).last }
      expect(response).to redirect_to(wizard_web_campaigns_vaccination_campaign_path(campaign, step: 2))
      expect(with_tenant(membership) { campaign.supply_provisioning }).to be_nil
    end

    it "completes wizard steps through provisioning approval" do
      with_tenant(membership) do
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 500
        )
        @campaign = create(
          :vaccination_campaign,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          target_doses: 100,
          room_capacity_per_day: 50,
          status: "draft",
          target_audience_definition: { "min_age" => 60 }
        )
      end
      campaign = with_tenant(membership) { @campaign }

      patch update_wizard_web_campaigns_vaccination_campaign_path(campaign, step: 2), params: {
        vaccination_campaign: { target_doses: 100, target_audience_definition: { min_age: 60, max_age: 80 } }
      }
      expect(response).to redirect_to(wizard_web_campaigns_vaccination_campaign_path(campaign, step: 3))
      expect(with_tenant(membership) { campaign.reload.target_audience_definition["wizard_audience_saved"] }).to be(true)

      patch update_wizard_web_campaigns_vaccination_campaign_path(campaign, step: 3)
      expect(response).to redirect_to(wizard_web_campaigns_vaccination_campaign_path(campaign, step: 4))
      expect(with_tenant(membership) { campaign.reload.supply_provisioning.status }).to eq("approved")
    end

    it "redirects deep-linked wizard steps beyond completion" do
      campaign = nil
      with_tenant(membership) do
        campaign = create(
          :vaccination_campaign,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          status: "draft",
          target_doses: 0,
          target_audience_definition: { "min_age" => 60 }
        )
      end
      campaign = with_tenant(membership) { campaign }

      get wizard_web_campaigns_vaccination_campaign_path(campaign, step: 4)

      expect(response).to redirect_to(wizard_web_campaigns_vaccination_campaign_path(campaign, step: 2))
    end

    it "blocks publish without campaign targets" do
      campaign = nil
      with_tenant(membership) do
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 500
        )
        campaign = create(
          :vaccination_campaign,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
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

      expect(response).to redirect_to(
        preview_provisioning_web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )
    end

    it "publishes generated routes for the field API" do
      campaign = nil
      route = nil
      with_tenant(membership) do
        product = create(:immunobiological_product, municipality: municipality)
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 100
        )
        campaign = create(
          :home_visit_campaign,
          municipality: municipality,
          health_facility: facility,
          status: "targets_built",
          target_audience_definition: { "immunobiological_product_id" => product.id }
        )
        team = create(:care_team, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: campaign, route_date: Date.current)
        route = campaign.visit_routes.first
        Inventory::Commands::ReserveVisitRouteSupplies.call(campaign: campaign)
      end

      post publish_routes_web_campaigns_home_visit_campaign_path(campaign)

      expect(response).to redirect_to(
        web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )
      expect(with_tenant(membership) { route.reload.status }).to eq("published")
      expect(with_tenant(membership) { campaign.reload.status }).to eq("scheduled")
    end

    it "blocks publish when provisioning is blocked" do
      campaign = nil
      route = nil
      with_tenant(membership) do
        product = create(:immunobiological_product, municipality: municipality)
        campaign = create(
          :home_visit_campaign,
          municipality: municipality,
          health_facility: facility,
          status: "routes_generated",
          target_audience_definition: { "immunobiological_product_id" => product.id }
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

      expect(response).to redirect_to(
        web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )
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

    it "shows reserve hint when published routes are not reserved" do
      campaign = with_tenant(membership) do
        team = create(:care_team, municipality: municipality, health_facility: facility, name: "Equipe Reserva")
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        camp = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "routes_generated")
        target = create(:campaign_target, municipality: municipality, health_facility: facility, campaign: camp, citizen: citizen)
        route = create(
          :visit_route,
          municipality: municipality,
          health_facility: facility,
          home_visit_campaign: camp,
          care_team: team,
          route_date: Date.current,
          status: "published"
        )
        create(
          :visit_route_stop,
          municipality: municipality,
          visit_route: route,
          citizen: citizen,
          campaign_target: target,
          stop_order: 1
        )
        VisitRouteProvisioning.create!(
          municipality: municipality,
          health_facility: facility,
          visit_route: route,
          status: "calculated",
          lines_json: [ { "key" => "kit", "label" => "Kit", "quantity_required" => 1, "unit" => "kit" } ]
        )
        camp
      end

      get web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("cidadaobr.campaigns.home_visit.dispatch_reserve_hint"))
      expect(response.body).to include(I18n.t("cidadaobr.campaigns.home_visit.reserve_provisioning"))
      expect(response.body).to include(I18n.t("cidadaobr.campaigns.home_visit.dispatch_needs_reserve"))
    end

    it "returns to campaign show after reserve from show" do
      campaign = with_tenant(membership) do
        product = create(:immunobiological_product, municipality: municipality)
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 100
        )
        team = create(:care_team, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        camp = create(
          :home_visit_campaign,
          municipality: municipality,
          health_facility: facility,
          status: "targets_built",
          target_audience_definition: { "immunobiological_product_id" => product.id }
        )
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: camp, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: camp, route_date: Date.current)
        camp
      end

      post reserve_provisioning_web_campaigns_home_visit_campaign_path(
        campaign,
        all_routes: true,
        return_to: "show",
        route_date: Date.current.iso8601
      )

      expect(response).to redirect_to(
        web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )
    end

    it "renders campaign show with team progress after routes exist" do
      campaign = with_tenant(membership) do
        team = create(:care_team, municipality: municipality, health_facility: facility, name: "Equipe Piloto")
        household = create(:household, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:household_member, household: household, citizen: citizen)
        camp = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: camp, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: camp, route_date: Date.current)
        camp.visit_routes.update_all(status: "published")
        stop = camp.visit_routes.first.visit_route_stops.first
        stop.update!(status: "visited")
        camp
      end

      get web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Progresso das equipes")
      expect(response.body).to include("Equipe Piloto")
    end

    it "renders route map with geo payload" do
      campaign = with_tenant(membership) do
        team = create(:care_team, municipality: municipality, health_facility: facility)
        household = create(:household, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:household_member, household: household, citizen: citizen)
        camp = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: camp, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: camp, route_date: Date.current)
        camp
      end

      get route_map_web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("visit-route-map")
    end

    it "completes domiciliary gate flow via HTTP" do
      campaign = nil
      team = nil
      with_tenant(membership) do
        product = create(:immunobiological_product, municipality: municipality)
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 100
        )
        team = create(:care_team, municipality: municipality, health_facility: facility)
        household = create(:household, municipality: municipality, health_facility: facility, care_team: team)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:household_member, household: household, citizen: citizen)
        campaign = create(
          :home_visit_campaign,
          municipality: municipality,
          health_facility: facility,
          status: "draft",
          target_audience_definition: { "immunobiological_product_id" => product.id }
        )
      end
      campaign = with_tenant(membership) { campaign }
      team = with_tenant(membership) { team }

      post build_targets_web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to redirect_to(web_campaigns_home_visit_campaign_path(campaign))
      expect(with_tenant(membership) { campaign.reload.campaign_targets.count }).to eq(1)

      post generate_routes_web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to redirect_to(web_campaigns_home_visit_campaign_path(campaign))
      expect(with_tenant(membership) { campaign.reload.visit_routes.count }).to eq(1)

      post calculate_provisioning_web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to redirect_to(
        preview_provisioning_web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )

      post reserve_provisioning_web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to redirect_to(preview_provisioning_web_campaigns_home_visit_campaign_path(campaign))
      expect(with_tenant(membership) { campaign.reload.home_visit_campaign_provisioning.status }).to eq("reserved")

      post publish_routes_web_campaigns_home_visit_campaign_path(campaign)
      expect(response).to redirect_to(
        web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )
      expect(with_tenant(membership) { campaign.reload.status }).to eq("scheduled")
      expect(with_tenant(membership) { campaign.visit_routes.pluck(:status) }).to all(eq("published"))

      expect {
        post dispatch_supplies_web_campaigns_home_visit_campaign_path(campaign, care_team_id: team.id)
      }.to change { with_tenant(membership) { TeamSupplyDispatch.count } }.by(1)

      expect(response).to redirect_to(
        web_campaigns_home_visit_campaign_path(campaign, route_date: Date.current.iso8601)
      )
    end

    it "registers supply dispatch after publish and reserve" do
      campaign = nil
      team = nil
      with_tenant(membership) do
        product = create(:immunobiological_product, municipality: municipality)
        create(
          :immunobiological_lot,
          municipality: municipality,
          health_facility: facility,
          immunobiological_product: product,
          quantity_on_hand: 100
        )
        campaign = create(
          :home_visit_campaign,
          municipality: municipality,
          health_facility: facility,
          status: "targets_built",
          target_audience_definition: { "immunobiological_product_id" => product.id }
        )
        team = create(:care_team, municipality: municipality, health_facility: facility)
        citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)
        Routing::Commands::GenerateVisitRoutes.call(campaign: campaign, route_date: Date.current)
        Inventory::Commands::ReserveVisitRouteSupplies.call(campaign: campaign)
        campaign.visit_routes.update_all(status: "published")
        campaign.update!(status: "scheduled")
      end

      result = with_tenant(membership) do
        Inventory::Commands::DispatchTeamSupplyKit.call(
          campaign: campaign,
          care_team: team,
          dispatch_date: Date.current
        )
      end

      expect(result.dispatch).to be_present
      get web_stock_team_supply_dispatches_path
      expect(response).to have_http_status(:ok)
    end
  end
end

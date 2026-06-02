# frozen_string_literal: true

require "rails_helper"

RSpec.describe Routing::Commands::GenerateVisitRoutes do
  let(:municipality) { create(:municipality) }
  let(:facility) do
    create(
      :health_facility,
      municipality: municipality,
      location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
    )
  end
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "creates ordered visit routes for campaign targets" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(
        :campaign_target,
        municipality: municipality,
        health_facility: facility,
        campaign: campaign,
        citizen: citizen
      )

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.skipped).to be(false)
      expect(result.routes_created).to eq(1)
      expect(result.stops_created).to eq(1)
      expect(campaign.visit_routes.first.visit_route_stops.pluck(:stop_order)).to eq([ 1 ])
    end
  end

  it "records home_visit.route.generated platform event" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)

      expect {
        described_class.call(campaign: campaign, route_date: Date.current)
      }.to change(DomainEvent, :count).by(1)

      expect(DomainEvent.order(:created_at).last.event_type).to eq(Cidadaobr::KafkaTopics::HOME_VISIT_ROUTE_GENERATED)
    end
  end

  it "does not create duplicate routes for the same date" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)

      first = described_class.call(campaign: campaign, route_date: Date.current)
      second = described_class.call(campaign: campaign, route_date: Date.current)

      expect(first.routes_created).to eq(1)
      expect(second.skipped).to be(true)
      expect(second.routes_created).to eq(0)
      expect(campaign.visit_routes.where(route_date: Date.current).count).to eq(1)
    end
  end

  it "creates one stop per household when multiple targets share a domicilio" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      household = create(:household, municipality: municipality, health_facility: facility, care_team: team)
      citizens = 3.times.map do |index|
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Citizen #{index}")
      end
      citizens.each do |citizen|
        create(:household_member, household: household, citizen: citizen)
        create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen, household: household)
      end

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.stops_created).to eq(1)
      expect(campaign.visit_routes.first.visit_route_stops.count).to eq(1)
      expect(campaign.campaign_targets.pluck(:status)).to all(eq("routed"))
    end
  end

  it "reports unassigned targets without routing them" do
    with_tenant(membership) do
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
      assigned = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      unassigned = create(:citizen, municipality: municipality, health_facility: facility, care_team: nil)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: assigned)
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: unassigned)

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.unassigned_count).to eq(1)
      expect(result.stops_created).to eq(1)
    end
  end

  it "returns a message when the facility has no location" do
    with_tenant(membership) do
      facility_without_location = create(:health_facility, municipality: municipality)
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility_without_location, status: "targets_built")
      citizen = create(:citizen, municipality: municipality, health_facility: facility_without_location, care_team: team)
      create(:campaign_target, municipality: municipality, health_facility: facility_without_location, campaign: campaign, citizen: citizen)

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_created).to eq(0)
      expect(result.message).to be_present
    end
  end

  it "returns no message when the facility has no location and no routable targets" do
    with_tenant(membership) do
      facility_without_location = create(:health_facility, municipality: municipality)
      campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility_without_location, status: "targets_built")
      unassigned = create(:citizen, municipality: municipality, health_facility: facility_without_location, care_team: nil)
      create(:campaign_target, municipality: municipality, health_facility: facility_without_location, campaign: campaign, citizen: unassigned)

      result = described_class.call(campaign: campaign, route_date: Date.current)

      expect(result.routes_created).to eq(0)
      expect(result.message).to be_nil
      expect(result.unassigned_count).to eq(1)
    end
  end
end

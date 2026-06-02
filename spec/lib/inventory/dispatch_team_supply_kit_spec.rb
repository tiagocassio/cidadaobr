# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::DispatchTeamSupplyKit do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product) { create(:immunobiological_product, municipality: municipality) }
  let(:care_team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "records visit_route.supplies.dispatched platform event" do
    with_tenant(membership) do
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "immunobiological_product_id" => product.id }
      )
      route = create(
        :visit_route,
        home_visit_campaign: campaign,
        care_team: care_team,
        municipality: municipality,
        health_facility: facility,
        route_date: Date.current,
        status: "published"
      )
      VisitRouteProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        visit_route: route,
        status: "reserved",
        lines_json: [
          {
            "key" => "immunobiological",
            "label" => product.name,
            "quantity_required" => 2,
            "quantity_reserved" => 2,
            "unit" => "dose",
            "immunobiological_product_id" => product.id
          }
        ]
      )

      expect {
        described_class.call(campaign: campaign, care_team: care_team, dispatch_date: Date.current)
      }.to change(DomainEvent, :count).by(1)

      event = DomainEvent.order(:created_at).last
      expect(event.event_type).to eq(Cidadaobr::KafkaTopics::VISIT_ROUTE_SUPPLIES_DISPATCHED)
      expect(event.care_team_id).to eq(care_team.id)
    end
  end
end

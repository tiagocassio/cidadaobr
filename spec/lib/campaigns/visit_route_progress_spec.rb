# frozen_string_literal: true

require "rails_helper"

RSpec.describe Campaigns::VisitRouteProgress do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  describe ".for_campaign" do
    it "returns zero completion when there are no stops" do
      with_tenant(membership) do
        campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)

        summary = described_class.for_campaign(campaign: campaign)

        expect(summary.total_stops).to eq(0)
        expect(summary.visited).to eq(0)
        expect(summary.completion_pct).to eq(0.0)
      end
    end

    it "counts visited and pending stops for the campaign" do
      with_tenant(membership) do
        campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
        team = create(:care_team, municipality: municipality, health_facility: facility, name: "Equipe A")
        route = create(
          :visit_route,
          municipality: municipality,
          health_facility: facility,
          home_visit_campaign: campaign,
          care_team: team,
          route_date: Date.current,
          status: "published"
        )
        create(:visit_route_stop, municipality: municipality, visit_route: route, status: "visited")
        create(:visit_route_stop, municipality: municipality, visit_route: route, status: "pending", stop_order: 2)
        create(:visit_route_stop, municipality: municipality, visit_route: route, status: "refused", stop_order: 3)

        summary = described_class.for_campaign(campaign: campaign, route_date: Date.current)

        expect(summary.total_stops).to eq(3)
        expect(summary.visited).to eq(1)
        expect(summary.pending).to eq(1)
        expect(summary.refused).to eq(1)
        expect(summary.completion_pct).to eq(33.3)
      end
    end
  end

  describe ".by_team" do
    it "groups completion by care team" do
      with_tenant(membership) do
        campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
        team_a = create(:care_team, municipality: municipality, health_facility: facility, name: "ESF Centro")
        team_b = create(:care_team, municipality: municipality, health_facility: facility, name: "ESF Norte")
        route_a = create(
          :visit_route,
          municipality: municipality,
          health_facility: facility,
          home_visit_campaign: campaign,
          care_team: team_a,
          route_date: Date.current,
          sequence_number: 1
        )
        route_b = create(
          :visit_route,
          municipality: municipality,
          health_facility: facility,
          home_visit_campaign: campaign,
          care_team: team_b,
          route_date: Date.current,
          sequence_number: 2
        )
        create(:visit_route_stop, municipality: municipality, visit_route: route_a, status: "visited")
        create(:visit_route_stop, municipality: municipality, visit_route: route_a, status: "pending", stop_order: 2)
        create(:visit_route_stop, municipality: municipality, visit_route: route_b, status: "pending")

        rows = described_class.by_team(campaign: campaign, route_date: Date.current)

        expect(rows.size).to eq(2)
        centro = rows.find { |r| r[:care_team_name] == "ESF Centro" }
        expect(centro[:total_stops]).to eq(2)
        expect(centro[:visited_stops]).to eq(1)
        expect(centro[:completion_pct]).to eq(50.0)
      end
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Routing::ClusterVisitRouteTargets do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }

  def build_target(citizen:)
    campaign = create(:home_visit_campaign, municipality: municipality, health_facility: facility)
    create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: citizen)
  end

  it "returns a single cluster for one target" do
    citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    target = build_target(citizen: citizen)

    clusters = described_class.call([ target ])

    expect(clusters[:unlocated]).to eq([ target ])
  end

  it "groups targets without location separately from geocoded clusters" do
    citizens = create_list(:citizen, 2, municipality: municipality, health_facility: facility, care_team: team)
    targets = citizens.map { |citizen| build_target(citizen: citizen) }

    clusters = described_class.call(targets)

    expect(clusters[:unlocated]).to match_array(targets)
  end
end

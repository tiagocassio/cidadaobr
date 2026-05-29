# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecalculateTeamScore do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "persists team indicator results for dsl_v1 rules" do
    with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Complete Citizen"
      )
    end

    results = with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[V_CAD])
    end

    expect(results.size).to eq(1)
    result = results.first
    expect(result.score).to eq(100.0)
    expect(result.tier).to eq("excellent")
    expect(result.quadrimester).to eq(Indicators::Quadrimester.current)
  end

  it "does not emit team score events when values are unchanged" do
    with_tenant(membership) do
      create(
        :citizen,
        municipality: municipality,
        health_facility: facility,
        care_team: team,
        birth_date: Date.new(1980, 1, 1),
        full_name: "Complete Citizen"
      )
    end

    with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[V_CAD])
    end

    allow(RecordPlatformEvent).to receive(:call)

    with_tenant(membership) do
      described_class.call(care_team_id: team.id, indicator_codes: %w[V_CAD])
    end

    expect(RecordPlatformEvent).not_to have_received(:call)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Campaigns::Commands::BuildCampaignTargetList do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "creates campaign targets from audience definition" do
    with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: 70.years.ago.to_date)
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: 20.years.ago.to_date)
      campaign = create(
        :vaccination_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "min_age" => 60 }
      )

      result = described_class.call(campaign: campaign)

      expect(result.created_count).to eq(1)
      expect(campaign.campaign_targets.count).to eq(1)
    end
  end
end

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

  it "removes pending targets outside the new audience scope" do
    with_tenant(membership) do
      elder = create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: 70.years.ago.to_date)
      young = create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: 20.years.ago.to_date)
      campaign = create(
        :vaccination_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "min_age" => 60 }
      )
      described_class.call(campaign: campaign)
      expect(campaign.campaign_targets.pluck(:citizen_id)).to eq([ elder.id ])

      campaign.update!(target_audience_definition: { "min_age" => 18 })
      result = described_class.call(campaign: campaign)

      expect(result.created_count).to eq(1)
      expect(campaign.campaign_targets.pluck(:citizen_id)).to match_array([ elder.id, young.id ])
    end
  end

  it "removes routed home-visit targets outside scope when no visit routes exist" do
    with_tenant(membership) do
      in_scope = create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: 62.years.ago.to_date)
      out_of_scope = create(:citizen, municipality: municipality, health_facility: facility, care_team: team, birth_date: 20.years.ago.to_date)
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "min_age" => 60 }
      )
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: in_scope, status: "routed")
      create(:campaign_target, municipality: municipality, health_facility: facility, campaign: campaign, citizen: out_of_scope, status: "pending")

      described_class.call(campaign: campaign)

      expect(campaign.campaign_targets.pluck(:citizen_id)).to eq([ in_scope.id ])
      expect(campaign.campaign_targets.pluck(:status)).to eq([ "routed" ])
    end
  end
end

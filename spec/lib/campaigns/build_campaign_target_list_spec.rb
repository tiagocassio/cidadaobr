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

  it "limits audience to citizens in domicílios of the selected micro-area" do
    with_tenant(membership) do
      in_micro = create(:household, municipality: municipality, health_facility: facility, care_team: team, micro_area_code: "01")
      other_micro = create(:household, municipality: municipality, health_facility: facility, care_team: team, micro_area_code: "02")
      in_scope = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      out_of_micro = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      only_team = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      create(:household_member, household: in_micro, citizen: in_scope)
      create(:household_member, household: other_micro, citizen: out_of_micro)

      campaign = create(
        :vaccination_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "micro_area_codes" => [ "01" ] }
      )

      expect(described_class.preview_scope(campaign: campaign).pluck(:id)).to eq([ in_scope.id ])
      expect(only_team.id).not_to be_in(described_class.preview_scope(campaign: campaign).pluck(:id))
    end
  end

  it "includes citizens linked to the campaign UBS only via care_team" do
    with_tenant(membership) do
      citizen = create(
        :citizen,
        municipality: municipality,
        health_facility: nil,
        care_team: team,
        birth_date: 65.years.ago.to_date
      )
      campaign = create(
        :home_visit_campaign,
        municipality: municipality,
        health_facility: facility,
        target_audience_definition: { "min_age" => 60 }
      )

      result = described_class.call(campaign: campaign)

      expect(result.created_count).to eq(1)
      expect(campaign.campaign_targets.pluck(:citizen_id)).to eq([ citizen.id ])
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

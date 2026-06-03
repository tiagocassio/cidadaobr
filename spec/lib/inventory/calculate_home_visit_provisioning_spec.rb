# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::CalculateHomeVisitProvisioning do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "persists campaign provisioning rollup" do
    campaign = with_tenant(membership) do
      create(:home_visit_campaign, municipality: municipality, health_facility: facility, status: "targets_built")
    end

    with_tenant(membership) do
      expect {
        described_class.call(campaign: campaign, route_date: Date.current)
      }.to change { HomeVisitCampaignProvisioning.count }.by(1)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Campaigns::Commands::InvalidateVaccinationCampaignDraft do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product) { create(:immunobiological_product, municipality: municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "clears provisioning and resets audience wizard flag" do
    with_tenant(membership) do
      campaign = create(
        :vaccination_campaign,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        status: "provisioning_approved",
        target_audience_definition: { "wizard_audience_saved" => true, "min_age" => 60 },
        target_doses: 50
      )
      SupplyProvisioning.create!(
        municipality: municipality,
        health_facility: facility,
        provisionable: campaign,
        status: "approved",
        required_items: [],
        available_items: [],
        shortages: [],
        capacity_ok: true
      )

      expect {
        described_class.call(campaign: campaign, keep_audience: false)
      }.to change(SupplyProvisioning, :count).by(-1)
        .and change(DomainEvent, :count).by(1)

      campaign.reload
      expect(campaign.status).to eq("draft")
      expect(campaign.target_doses).to eq(0)
      expect(campaign.target_audience_definition["wizard_audience_saved"]).to be_nil
      expect(DomainEvent.order(:created_at).last.event_type).to eq(Cidadaobr::KafkaTopics::VACCINATION_CAMPAIGN_DRAFT_INVALIDATED)
    end
  end
end

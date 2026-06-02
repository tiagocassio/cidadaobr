# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::Commands::PersistVaccinationProvisioning do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:product) { create(:immunobiological_product, municipality: municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  it "approves provisioning and emits vaccination.provisioning.approved" do
    with_tenant(membership) do
      create(
        :immunobiological_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        quantity_on_hand: 500
      )
      campaign = create(
        :vaccination_campaign,
        municipality: municipality,
        health_facility: facility,
        immunobiological_product: product,
        target_doses: 100,
        status: "draft"
      )

      result = nil
      expect {
        result = described_class.call(campaign: campaign)
      }.to change(SupplyProvisioning, :count).by(1)
        .and change(DomainEvent, :count).by(1)

      expect(result.feasible).to be(true)
      expect(campaign.reload.status).to eq("provisioning_approved")
      expect(DomainEvent.order(:created_at).last.event_type).to eq(Cidadaobr::KafkaTopics::VACCINATION_PROVISIONING_APPROVED)
    end
  end
end

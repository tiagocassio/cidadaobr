# frozen_string_literal: true

require "rails_helper"

RSpec.describe Inventory::ProvisioningValidator do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }
  let(:product) { create(:immunobiologic_product, municipality: municipality) }

  def build_campaign(**attrs)
    defaults = {
      municipality: municipality,
      health_facility: facility,
      immunobiologic_product: product,
      name: "Campanha demo",
      campaign_kind: "human_immunization",
      starts_on: Date.current,
      ends_on: Date.current + 6.days,
      target_doses: 300,
      room_capacity_per_day: 50,
      status: "draft"
    }
    VaccinationCampaign.new(defaults.merge(attrs))
  end

  it "approves when stock and room capacity cover target doses" do
    with_tenant(membership) do
      create(
        :immunobiologic_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: product,
        quantity_on_hand: 500,
        expires_on: 1.year.from_now.to_date
      )
      campaign = build_campaign

      result = described_class.call(
        campaign: campaign,
        available_doses: described_class.available_doses_for(campaign: campaign)
      )

      expect(result.feasible).to be(true)
      expect(result.capacity_ok).to be(true)
      expect(result.shortages).to be_empty
    end
  end

  it "rejects when available doses are below target" do
    campaign = build_campaign(target_doses: 400)

    result = described_class.call(campaign: campaign, available_doses: 100)

    expect(result.feasible).to be(false)
    expect(result.shortages.first).to include("required 400")
  end

  it "rejects when room capacity cannot deliver target doses in the window" do
    campaign = build_campaign(target_doses: 500, room_capacity_per_day: 10)

    result = described_class.call(campaign: campaign, available_doses: 1_000)

    expect(result.feasible).to be(false)
    expect(result.capacity_ok).to be(false)
    expect(result.shortages.join).to include("Room capacity")
  end

  it "rejects when another approved campaign already committed doses at the facility" do
    with_tenant(membership) do
      create(
        :immunobiologic_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: product,
        quantity_on_hand: 500,
        expires_on: 1.year.from_now.to_date
      )
      existing = build_campaign(target_doses: 400, status: "provisioning_approved")
      existing.save!
      campaign = build_campaign(target_doses: 200)

      result = described_class.call(
        campaign: campaign,
        available_doses: described_class.available_doses_for(campaign: campaign)
      )

      expect(result.feasible).to be(false)
      expect(result.shortages.first).to include("required 200")
    end
  end

  it "persists supply provisioning with approved status" do
    with_tenant(membership) do
      create(
        :immunobiologic_lot,
        municipality: municipality,
        health_facility: facility,
        immunobiologic_product: product,
        quantity_on_hand: 500,
        expires_on: 1.year.from_now.to_date
      )
      campaign = build_campaign
      campaign.save!

      result = nil
      expect {
        result = described_class.persist!(campaign: campaign)
      }.to change(SupplyProvisioning, :count).by(1)

      expect(result.feasible).to be(true)
      expect(campaign.reload.supply_provisioning.status).to eq("approved")
    end
  end

  it "emits supply.provisioning.rejected when blocked" do
    with_tenant(membership) do
      campaign = build_campaign(target_doses: 500)
      campaign.save!

      expect {
        described_class.persist!(campaign: campaign)
      }.to change(OutboxMessage, :count).by(1)

      message = OutboxMessage.last
      expect(message.event_type).to eq("supply.provisioning.rejected")
      expect(message.topic).to eq("supply.provisioning.rejected")
    end
  end

  it "uses scheduled room capacity slots when present" do
    with_tenant(membership) do
      room = ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Vacina", room_kind: "vaccination")
      campaign = build_campaign(target_doses: 400, room_capacity_per_day: 10, consultation_room: room)
      (campaign.starts_on..campaign.ends_on).each do |date|
        RoomCapacitySlot.create!(
          municipality: municipality,
          health_facility: facility,
          consultation_room: room,
          slot_date: date,
          starts_at: Time.zone.parse("#{date} 08:00"),
          ends_at: Time.zone.parse("#{date} 12:00"),
          capacity: 100,
          booked_count: 0
        )
      end

      result = described_class.call(campaign: campaign, available_doses: 500)

      expect(result.capacity_ok).to be(true)
    end
  end
end

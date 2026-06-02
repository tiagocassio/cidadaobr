# frozen_string_literal: true

module Inventory
  module Commands
    class PersistVaccinationProvisioning < ApplicationCommand
      def initialize(campaign:)
        @campaign = campaign
      end

      def call
        write_transaction do
          @campaign.lock! if @campaign.persisted?
          ProvisioningValidator.lock_stock_for_facility_product!(
            municipality_id: @campaign.municipality_id,
            health_facility_id: @campaign.health_facility_id,
            immunobiological_product_id: @campaign.immunobiological_product_id,
            exclude_vaccination_campaign_id: @campaign.id
          )

          result = ProvisioningValidator.call(
            campaign: @campaign,
            available_doses: ProvisioningValidator.available_doses_for(campaign: @campaign),
            room_capacity_per_day: @campaign.room_capacity_per_day
          )

          @campaign.supply_provisioning&.destroy

          provisioning = SupplyProvisioning.create!(
            municipality: @campaign.municipality,
            health_facility: @campaign.health_facility,
            provisionable: @campaign,
            status: result.feasible ? "approved" : "rejected",
            required_items: result.lines.map(&:to_h),
            available_items: result.lines.map { |line| line.to_h.merge(available: line.available) },
            shortages: result.shortages,
            capacity_ok: result.capacity_ok,
            rejection_reason: result.feasible ? nil : result.shortages.join("; ")
          )

          if result.feasible
            emit_approved!(campaign: @campaign, provisioning: provisioning)
          else
            ProvisioningValidator.emit_rejection_event!(campaign: @campaign, provisioning: provisioning)
          end

          @campaign.update!(status: result.feasible ? "provisioning_approved" : "draft")
          result
        end
      end

      private

      def emit_approved!(campaign:, provisioning:)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::VACCINATION_PROVISIONING_APPROVED,
          aggregate_type: "SupplyProvisioning",
          aggregate_id: provisioning.id,
          payload: {
            campaign_id: campaign.id,
            provisionable_type: campaign.class.name,
            health_facility_id: campaign.health_facility_id,
            target_doses: campaign.target_doses
          },
)
      end
    end
  end
end

# frozen_string_literal: true

module Campaigns
  module Commands
    class InvalidateVaccinationCampaignDraft < ApplicationCommand
      def initialize(campaign:, keep_audience: false)
        @campaign = campaign
        @keep_audience = keep_audience
      end

      def call
        return if @campaign.status == "active"

        had_provisioning = @campaign.supply_provisioning.present?
        updates = build_updates(had_provisioning: had_provisioning)
        @campaign.assign_attributes(updates) unless @keep_audience

        write_transaction do
          BuildCampaignTargetList.remove_stale_for!(campaign: @campaign)
          @campaign.supply_provisioning&.destroy
          @campaign.update!(updates) if updates.any?
        end

        emit_invalidated! if had_provisioning || updates.any?
        @campaign.reload
      end

      private

      def build_updates(had_provisioning:)
        if @keep_audience
          return {} unless had_provisioning

          { status: "draft" }
        else
          definition = @campaign.target_audience_definition.deep_dup
          definition.delete("wizard_audience_saved")
          {
            target_audience_definition: definition,
            target_doses: 0,
            status: "draft"
          }
        end
      end

      def emit_invalidated!
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::VACCINATION_CAMPAIGN_DRAFT_INVALIDATED,
          aggregate_type: "VaccinationCampaign",
          aggregate_id: @campaign.id,
          payload: {
            campaign_id: @campaign.id,
            keep_audience: @keep_audience
          },
)
      end
    end
  end
end

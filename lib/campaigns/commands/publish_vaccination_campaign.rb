# frozen_string_literal: true

module Campaigns
  module Commands
    class PublishVaccinationCampaign < ApplicationCommand
      Result = Data.define(:success, :message)

      def initialize(campaign:)
        @campaign = campaign
      end

      def call
        if @campaign.status == "active"
          return Result.new(false, I18n.t("cidadaobr.campaigns.flash.already_published"))
        end
        unless @campaign.supply_provisioning&.status == "approved"
          return Result.new(false, I18n.t("cidadaobr.campaigns.flash.publish_blocked"))
        end
        unless @campaign.campaign_targets.exists?
          return Result.new(false, I18n.t("cidadaobr.campaigns.flash.publish_no_targets"))
        end

        write_transaction do
          @campaign.update!(status: "active")
          emit_published!(@campaign)
        end

        Result.new(true, nil)
      end

      private

      def emit_published!(campaign)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::VACCINATION_CAMPAIGN_PUBLISHED,
          aggregate_type: "VaccinationCampaign",
          aggregate_id: campaign.id,
          payload: {
            campaign_id: campaign.id,
            health_facility_id: campaign.health_facility_id
          },
)
      end
    end
  end
end

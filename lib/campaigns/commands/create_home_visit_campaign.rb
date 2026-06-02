# frozen_string_literal: true

module Campaigns
  module Commands
    class CreateHomeVisitCampaign < ApplicationCommand
      Result = Data.define(:success, :campaign)

      def initialize(campaign:, municipality:)
        @campaign = campaign
        @municipality = municipality
      end

      def call
        @campaign.municipality = @municipality
        @campaign.status = "draft"
        success = @campaign.save
        Result.new(success: success, campaign: @campaign)
      end
    end
  end
end

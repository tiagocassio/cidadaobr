# frozen_string_literal: true

module Campaigns
  module Commands
    class UpdateHomeVisitCampaign < ApplicationCommand
      Result = Data.define(:success, :campaign)

      def initialize(campaign:, attributes:)
        @campaign = campaign
        @attributes = attributes
      end

      def call
        success = @campaign.update(@attributes)
        Result.new(success: success, campaign: @campaign)
      end
    end
  end
end

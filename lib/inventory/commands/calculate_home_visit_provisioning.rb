# frozen_string_literal: true

module Inventory
  module Commands
    class CalculateHomeVisitProvisioning < ApplicationCommand
      Result = Data.define(:record)

      def initialize(campaign:, route_date:)
        @campaign = campaign
        @route_date = route_date
      end

      def call
        record = nil

        write_transaction do
          Inventory::PreviewCampaignProvisioning.refresh_route_provisionings!(
            campaign: @campaign,
            route_date: @route_date
          )
          record = Inventory::PreviewCampaignProvisioning.rollup!(
            campaign: @campaign,
            route_date: rollup_route_date
          )
        end

        Result.new(record: record)
      end

      private

      def rollup_route_date
        return nil unless @campaign.visit_routes.exists?

        @campaign.visit_routes.exists?(route_date: @route_date) ? @route_date : nil
      end
    end
  end
end

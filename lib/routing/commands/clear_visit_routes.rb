# frozen_string_literal: true

module Routing
  module Commands
    class ClearVisitRoutes < ApplicationCommand
      Result = Data.define(:routes_removed, :targets_reset, :message)

      def initialize(campaign:, route_date:, sync_provisioning: true, within_existing_transaction: false)
        @campaign = campaign
        @route_date = route_date
        @sync_provisioning = sync_provisioning
        @within_existing_transaction = within_existing_transaction
      end

      def call
        routes = @campaign.visit_routes.where(route_date: @route_date)
        if routes.joins(:visit_route_provisioning).where(visit_route_provisioning: { status: "dispatched" }).exists?
          return Result.new(
            0,
            0,
            I18n.t("cidadaobr.campaigns.home_visit.flash.clear_routes_dispatched")
          )
        end

        if @within_existing_transaction
          perform_clear!
        else
          write_transaction { perform_clear! }
        end
      end

      def self.sync_provisioning!(campaign)
        campaign.reload
        if campaign.visit_routes.none?
          campaign.home_visit_campaign_provisioning&.destroy
        else
          Inventory::PreviewCampaignProvisioning.rollup!(campaign: campaign)
        end
      end

      private

      def perform_clear!
        routes = @campaign.visit_routes.where(route_date: @route_date)
        target_ids = VisitRouteStop
          .where(visit_route_id: routes.select(:id))
          .where.not(campaign_target_id: nil)
          .pluck(:campaign_target_id)
        routes_removed = routes.count

        Inventory::Commands::ReleaseReservedSupplies.call_for_routes(routes: routes)
        routes.destroy_all
        targets_reset = 0
        if target_ids.any?
          targets_reset = CampaignTarget
            .where(id: target_ids)
            .update_all(status: "pending", updated_at: Time.current)
        end

        if @campaign.visit_routes.none? && @campaign.status == "routes_generated"
          @campaign.update!(status: "targets_built")
        end

        self.class.sync_provisioning!(@campaign) if @sync_provisioning

        Result.new(routes_removed, targets_reset, nil)
      end
    end
  end
end

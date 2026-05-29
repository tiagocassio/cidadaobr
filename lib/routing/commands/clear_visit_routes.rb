# frozen_string_literal: true

module Routing
  module Commands
    class ClearVisitRoutes
      Result = Data.define(:routes_removed, :targets_reset)

      class << self
        def call(campaign:, route_date:)
          ActiveRecord::Base.transaction do
            clear!(campaign: campaign, route_date: route_date)
          end
        end

        def clear!(campaign:, route_date:, sync_provisioning: true)
          routes = campaign.visit_routes.where(route_date: route_date)
          target_ids = VisitRouteStop
            .where(visit_route_id: routes.select(:id))
            .where.not(campaign_target_id: nil)
            .pluck(:campaign_target_id)
          routes_removed = routes.count

          routes.destroy_all
          targets_reset = 0
          if target_ids.any?
            targets_reset = CampaignTarget
              .where(id: target_ids)
              .update_all(status: "pending", updated_at: Time.current)
          end

          if campaign.visit_routes.none? && campaign.status == "routes_generated"
            campaign.update!(status: "targets_built")
          end

          sync_provisioning!(campaign) if sync_provisioning

          Result.new(routes_removed, targets_reset)
        end

        def sync_provisioning!(campaign)
          campaign.reload
          if campaign.visit_routes.none?
            campaign.home_visit_campaign_provisioning&.destroy
          else
            Inventory::PreviewCampaignProvisioning.rollup!(campaign: campaign)
          end
        end

      end
    end
  end
end

# frozen_string_literal: true

module Routing
  module Commands
    class PublishVisitRoutes
      Result = Data.define(:routes_published, :message)

      class << self
        def call(campaign:, route_date:)
          if campaign.visit_routes.where(route_date: route_date, status: "draft").none?
            return Result.new(
              0,
              I18n.t("cidadaobr.campaigns.home_visit.flash.no_draft_routes", date: I18n.l(route_date))
            )
          end

          message = nil
          routes_published = 0

          ActiveRecord::Base.transaction do
            Inventory::ProvisioningValidator.lock_stock_for_home_visit!(campaign: campaign)
            Inventory::PreviewCampaignProvisioning.rollup!(campaign: campaign)
            provisioning = campaign.reload.home_visit_campaign_provisioning
            unless provisioning&.status == "calculated"
              message = if provisioning&.status == "blocked"
                I18n.t("cidadaobr.campaigns.home_visit.flash.publish_blocked_provisioning")
              else
                I18n.t("cidadaobr.campaigns.home_visit.flash.publish_provisioning_not_calculated")
              end
              raise ActiveRecord::Rollback
            end

            routes_published = campaign.visit_routes
              .where(route_date: route_date, status: "draft")
              .update_all(status: "published", updated_at: Time.current)

            next unless campaign.visit_routes.where(status: "draft").none?
            next unless campaign.status.in?(%w[routes_generated draft targets_built])

            campaign.update!(status: "scheduled")
          end

          return Result.new(0, message) if message

          Result.new(routes_published, nil)
        end
      end
    end
  end
end

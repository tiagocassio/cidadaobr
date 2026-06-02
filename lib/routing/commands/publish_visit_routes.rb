# frozen_string_literal: true

module Routing
  module Commands
    class PublishVisitRoutes < ApplicationCommand
      Result = Data.define(:routes_published, :message)

      def initialize(campaign:, route_date:)
        @campaign = campaign
        @route_date = route_date
      end

      def call
        if @campaign.visit_routes.where(route_date: @route_date, status: "draft").none?
          return Result.new(
            0,
            I18n.t("cidadaobr.campaigns.home_visit.flash.no_draft_routes", date: I18n.l(@route_date))
          )
        end

        message = nil
        routes_published = 0

        write_transaction do
          draft_routes = @campaign.visit_routes
            .where(route_date: @route_date, status: "draft")
            .includes(:visit_route_provisioning)
            .to_a

          unless draft_routes.all? { |route| route.visit_route_provisioning&.status == "reserved" }
            message = I18n.t("cidadaobr.campaigns.home_visit.flash.publish_route_provisioning_not_reserved")
            raise ActiveRecord::Rollback
          end

          Inventory::ProvisioningValidator.lock_stock_for_home_visit!(campaign: @campaign)
          Inventory::PreviewCampaignProvisioning.rollup!(campaign: @campaign, route_date: @route_date)
          provisioning = @campaign.reload.home_visit_campaign_provisioning
          unless provisioning&.status == "reserved"
            message = if provisioning&.status == "blocked"
              I18n.t("cidadaobr.campaigns.home_visit.flash.publish_blocked_provisioning")
            elsif provisioning&.status == "calculated"
              I18n.t("cidadaobr.campaigns.home_visit.flash.publish_provisioning_not_reserved")
            else
              I18n.t("cidadaobr.campaigns.home_visit.flash.publish_provisioning_not_calculated")
            end
            raise ActiveRecord::Rollback
          end

          routes_published = @campaign.visit_routes
            .where(route_date: @route_date, status: "draft")
            .update_all(status: "published", updated_at: Time.current)

          next unless @campaign.visit_routes.where(status: "draft").none?
          next unless @campaign.status.in?(%w[routes_generated draft targets_built])

          @campaign.update!(status: "scheduled")
        end

        return Result.new(0, message) if message

        emit_routes_published!(routes_published) if routes_published.positive?

        Result.new(routes_published, nil)
      end

      private

      def emit_routes_published!(routes_published)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::HOME_VISIT_ROUTE_PUBLISHED,
          aggregate_type: @campaign.class.name,
          aggregate_id: @campaign.id,
          payload: {
            campaign_id: @campaign.id,
            route_date: @route_date.iso8601,
            routes_published: routes_published
          },
)
      end
    end
  end
end

# frozen_string_literal: true

module Routing
  module Commands
    class GenerateVisitRoutes < ApplicationCommand
      Result = Data.define(:routes_created, :stops_created, :unassigned_count, :skipped, :message)

      def initialize(campaign:, route_date:, max_stops_per_route: 50, regenerate: false)
        @campaign = campaign
        @route_date = route_date
        @max_stops_per_route = max_stops_per_route
        @regenerate = regenerate
      end

      def call
        if @campaign.visit_routes.where(route_date: @route_date).exists? && !@regenerate
          return Result.new(
            0,
            0,
            0,
            true,
            I18n.t("cidadaobr.campaigns.home_visit.flash.routes_already_exist", date: I18n.l(@route_date))
          )
        end

        targets = CampaignTarget
          .where(campaign: @campaign, status: %w[pending routed])
          .includes(citizen: { households: [] })
          .order(priority_score: :desc, created_at: :asc)

        unassigned_count = targets.count { |target| target.citizen.care_team_id.blank? }
        routable_targets = targets.select { |target| target.citizen.care_team_id.present? }

        depot = facility_location(@campaign.health_facility)
        unless depot
          message = if routable_targets.any?
            I18n.t("cidadaobr.campaigns.home_visit.flash.no_facility_location")
          end
          return Result.new(0, 0, unassigned_count, false, message)
        end

        routes_created = 0
        stops_created = 0

        write_transaction do
          cleared_on_regenerate = false
          if @regenerate
            ClearVisitRoutes.call(
              campaign: @campaign,
              route_date: @route_date,
              sync_provisioning: false,
              within_existing_transaction: true
            )
            cleared_on_regenerate = true
          end

          grouped = routable_targets.group_by { |target| target.citizen.care_team_id }

          grouped.each do |care_team_id, team_targets|
            care_team = CareTeam.find(care_team_id)
            targets_by_household = team_targets.group_by { |target| household_key_for(target) }
            visit_targets = targets_by_household.values.map { |group| pick_representative_target(group) }
            geo_clusters = Routing::ClusterVisitRouteTargets.call(visit_targets).values
            chunks = geo_clusters.flat_map { |cluster| cluster.each_slice(@max_stops_per_route).to_a }

            chunks.each_with_index do |chunk, index|
              route = VisitRoute.create!(
                municipality: @campaign.municipality,
                health_facility: @campaign.health_facility,
                home_visit_campaign: @campaign,
                care_team: care_team,
                route_date: @route_date,
                sequence_number: index + 1,
                status: "draft"
              )
              routes_created += 1

              ordered = Routing::OrderVisitRouteStops.call(chunk, start_point: depot)
              ordered.each_with_index do |target, stop_index|
                household = target.household || household_for(target.citizen)
                VisitRouteStop.create!(
                  municipality: @campaign.municipality,
                  visit_route: route,
                  stop_order: stop_index + 1,
                  household: household,
                  citizen: target.citizen,
                  campaign_target: target,
                  status: "pending"
                )
                targets_by_household[household_key_for(target)].each { |member| member.update!(status: "routed") }
                stops_created += 1
              end

              Inventory::PreviewCampaignProvisioning.persist_route!(route: route)
            end
          end

          if routes_created.positive?
            @campaign.update!(status: "routes_generated")
            Inventory::PreviewCampaignProvisioning.rollup!(campaign: @campaign)
            emit_routes_generated!(routes_created: routes_created, stops_created: stops_created)
          elsif cleared_on_regenerate
            ClearVisitRoutes.sync_provisioning!(@campaign)
          end
        end

        Result.new(routes_created, stops_created, unassigned_count, false, nil)
      end

      private

      def household_for(citizen)
        citizen.household_members.order(:created_at).first&.household
      end

      def household_key_for(target)
        household = target.household || household_for(target.citizen)
        household&.id || "citizen:#{target.citizen_id}"
      end

      def pick_representative_target(targets)
        targets.max_by { |target| [ target.priority_score.to_i, -target.created_at.to_i ] }
      end

      def facility_location(facility)
        return unless facility&.location

        [ facility.location.y, facility.location.x ]
      end

      def emit_routes_generated!(routes_created:, stops_created:)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::HOME_VISIT_ROUTE_GENERATED,
          aggregate_type: @campaign.class.name,
          aggregate_id: @campaign.id,
          payload: {
            campaign_id: @campaign.id,
            route_date: @route_date.iso8601,
            routes_created: routes_created,
            stops_created: stops_created
          },
)
      end
    end
  end
end

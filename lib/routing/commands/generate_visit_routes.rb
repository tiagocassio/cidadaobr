# frozen_string_literal: true

module Routing
  module Commands
    class GenerateVisitRoutes
      Result = Data.define(:routes_created, :stops_created, :unassigned_count, :skipped, :message)

      class << self
        def call(campaign:, route_date:, max_stops_per_route: 50, regenerate: false)
          if campaign.visit_routes.where(route_date: route_date).exists? && !regenerate
            return Result.new(
              0,
              0,
              0,
              true,
              I18n.t("cidadaobr.campaigns.home_visit.flash.routes_already_exist", date: I18n.l(route_date))
            )
          end

          targets = CampaignTarget
            .where(campaign: campaign, status: %w[pending routed])
            .includes(citizen: { households: [] })
            .order(priority_score: :desc, created_at: :asc)

          unassigned_count = targets.count { |target| target.citizen.care_team_id.blank? }
          routable_targets = targets.select { |target| target.citizen.care_team_id.present? }

          routes_created = 0
          stops_created = 0

          ActiveRecord::Base.transaction do
            cleared_on_regenerate = false
            if regenerate
              ClearVisitRoutes.clear!(
                campaign: campaign,
                route_date: route_date,
                sync_provisioning: false
              )
              cleared_on_regenerate = true
            end

            grouped = routable_targets.group_by { |target| target.citizen.care_team_id }

            grouped.each do |care_team_id, team_targets|
              care_team = CareTeam.find(care_team_id)
              chunks = team_targets.each_slice(max_stops_per_route).to_a

              chunks.each_with_index do |chunk, index|
                route = VisitRoute.create!(
                  municipality: campaign.municipality,
                  health_facility: campaign.health_facility,
                  home_visit_campaign: campaign,
                  care_team: care_team,
                  route_date: route_date,
                  sequence_number: index + 1,
                  status: "draft"
                )
                routes_created += 1

                ordered = order_stops_nearest_neighbor(chunk)
                ordered.each_with_index do |target, stop_index|
                  household = target.household || household_for(target.citizen)
                  VisitRouteStop.create!(
                    municipality: campaign.municipality,
                    visit_route: route,
                    stop_order: stop_index + 1,
                    household: household,
                    citizen: target.citizen,
                    campaign_target: target,
                    status: "pending"
                  )
                  target.update!(status: "routed")
                  stops_created += 1
                end

                Inventory::PreviewCampaignProvisioning.persist_route!(route: route)
              end
            end

            if routes_created.positive?
              campaign.update!(status: "routes_generated")
              Inventory::PreviewCampaignProvisioning.rollup!(campaign: campaign)
            elsif cleared_on_regenerate
              ClearVisitRoutes.sync_provisioning!(campaign)
            end
          end

          Result.new(routes_created, stops_created, unassigned_count, false, nil)
        end

        private

        def household_for(citizen)
          citizen.household_members.order(:created_at).first&.household
        end

        def order_stops_nearest_neighbor(targets)
          return targets if targets.size <= 1

          remaining = targets.dup
          ordered = [ remaining.shift ]
          current_point = location_for(ordered.last)

          until remaining.empty?
            next_target = remaining.min_by do |target|
              point = location_for(target)
              point && current_point ? haversine_km(current_point, point) : Float::INFINITY
            end
            ordered << next_target
            remaining.delete(next_target)
            current_point = location_for(next_target) || current_point
          end

          ordered
        end

        def location_for(target)
          household = target.household || household_for(target.citizen)
          return unless household&.location

          [ household.location.y, household.location.x ]
        end

        def haversine_km(a, b)
          lat1, lon1 = a
          lat2, lon2 = b
          rad = Math::PI / 180.0
          dlat = (lat2 - lat1) * rad
          dlon = (lon2 - lon1) * rad
          lat1 *= rad
          lat2 *= rad
          h = Math.sin(dlat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon / 2)**2
          6371.0 * 2 * Math.asin(Math.sqrt(h))
        end
      end
    end
  end
end

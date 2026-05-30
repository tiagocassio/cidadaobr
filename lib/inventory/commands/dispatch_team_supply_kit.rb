# frozen_string_literal: true

module Inventory
  module Commands
    class DispatchTeamSupplyKit
      Result = Data.define(:dispatch, :message)

      class << self
        def call(campaign:, care_team:, dispatch_date:)
          routes = campaign.visit_routes.where(
            care_team_id: care_team.id,
            route_date: dispatch_date,
            status: "published"
          ).includes(:visit_route_provisioning)

          if routes.none?
            return Result.new(nil, I18n.t("cidadaobr.campaigns.home_visit.flash.no_published_routes"))
          end

          unless routes.all? { |route| route.visit_route_provisioning&.status == "reserved" }
            if routes.all? { |route| route.visit_route_provisioning&.status == "dispatched" }
              dispatch = TeamSupplyDispatch.find_by(
                municipality: campaign.municipality,
                health_facility: campaign.health_facility,
                care_team: care_team,
                dispatch_date: dispatch_date
              )
              return Result.new(dispatch, nil) if dispatch&.status == "dispatched"
            end

            return Result.new(nil, I18n.t("cidadaobr.campaigns.home_visit.flash.dispatch_not_reserved"))
          end

          totals = build_totals(routes)
          return Result.new(nil, I18n.t("cidadaobr.campaigns.home_visit.flash.dispatch_empty_kit")) if totals.empty?

          dispatch = nil

          ActiveRecord::Base.transaction do
            dispatch = TeamSupplyDispatch.find_or_initialize_by(
              municipality: campaign.municipality,
              health_facility: campaign.health_facility,
              care_team: care_team,
              dispatch_date: dispatch_date
            )
            dispatch.assign_attributes(lines_json: totals.values, status: "dispatched")
            dispatch.save!

            routes.each do |route|
              route.visit_route_provisioning.update!(status: "dispatched")
              StockMovement.where(
                reference_type: "VisitRouteProvisioning",
                reference_id: route.visit_route_provisioning.id,
                movement_type: "reserve"
              ).update_all(movement_type: "dispatch", updated_at: Time.current)
            end
          end

          Result.new(dispatch, nil)
        end

        private

        def build_totals(routes)
          totals = Hash.new { |hash, key| hash[key] = { "label" => key, "quantity" => 0, "unit" => "unit" } }

          routes.each do |route|
            route.visit_route_provisioning.lines_json.each do |line|
              line = line.stringify_keys
              reserved = line["quantity_reserved"].to_i
              next if reserved <= 0

              bucket = totals[line["key"]]
              bucket["label"] = line["label"]
              bucket["unit"] = line["unit"]
              bucket["quantity"] += reserved
            end
          end

          totals
        end
      end
    end
  end
end

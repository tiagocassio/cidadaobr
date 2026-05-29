# frozen_string_literal: true

module Api
  module V1
    module Field
      class VisitRoutesController < Api::BaseController
        def index
          @routes = scoped_routes
            .includes(:care_team, visit_route_stops: :citizen)
            .where(status: %w[published in_progress draft])
            .order(:route_date, :sequence_number)
        end

        def show
          @route = scoped_routes.includes(visit_route_stops: :citizen).find(params[:id])
          @provisioning = @route.visit_route_provisioning
        end

        private

        def scoped_routes
          scope = VisitRoute.where(municipality_id: current_membership.municipality_id)
          if current_membership.scope == "team"
            scope = scope.where(care_team_id: current_membership.user.team_ids_for(current_membership.municipality_id))
          elsif current_membership.health_facility_id.present?
            scope = scope.where(health_facility_id: current_membership.health_facility_id)
          end
          scope
        end
      end
    end
  end
end

# frozen_string_literal: true

module Web
  module Stock
    class TeamSupplyDispatchesController < BaseController
      before_action :require_facility_or_municipality!

      def index
        scope = TeamSupplyDispatch
          .where(municipality_id: current_municipality.id)
          .includes(:health_facility, :care_team)
          .order(dispatch_date: :desc, created_at: :desc)
        scope = scope.where(health_facility_id: scoped_health_facilities.select(:id)) unless municipality_scope?
        @pagy, @dispatches = pagy(scope)
      end

      def show
        @dispatch = scoped_dispatches.find(params[:id])
      end

      private

      def scoped_dispatches
        scope = TeamSupplyDispatch.where(municipality_id: current_municipality.id)
        return scope if municipality_scope?

        scope.where(health_facility_id: scoped_health_facilities.select(:id))
      end
    end
  end
end

# frozen_string_literal: true

module Web
  module Indicators
    class TeamsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :set_team

      def show
        @quadrimester = resolve_quadrimester_param
        @results = scoped_team_indicator_results
          .where(care_team_id: @team.id, quadrimester: @quadrimester)
          .order(:indicator_code)
        active_codes = IndicatorCatalog.active_portaria.select(:code)
        gaps_scope = scoped_citizen_indicator_gaps.where(care_team_id: @team.id, status: "open", indicator_code: active_codes)
        indicator_code = params.permit(:indicator_code, :quadrimester)[:indicator_code]
        gaps_scope = gaps_scope.where(indicator_code: indicator_code) if indicator_code.present?
        @open_gaps = gaps_scope.includes(:citizen).order(:indicator_code, :due_on)
        @gaps_by_indicator = @open_gaps.group_by(&:indicator_code)
        @gap_indicator_codes = @gaps_by_indicator.keys.sort
        @catalog_codes = IndicatorCatalog.active_portaria.order(:display_order).pluck(:code)
      end

      private

      def set_team
        @team = scoped_care_teams.find(params[:id])
      end
    end
  end
end

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
        @open_gaps = scoped_citizen_indicator_gaps
          .where(care_team_id: @team.id, status: "open")
          .includes(:citizen)
          .order(:indicator_code, :due_on)
      end

      private

      def set_team
        @team = scoped_care_teams.find(params[:id])
      end
    end
  end
end

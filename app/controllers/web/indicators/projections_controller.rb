# frozen_string_literal: true

module Web
  module Indicators
    class ProjectionsController < BaseController
      before_action :require_municipality_scope!

      def show
        @quadrimester = resolve_quadrimester_param
        @results = scoped_team_indicator_results.where(quadrimester: @quadrimester).includes(:care_team)
        @by_team = @results.group_by(&:care_team_id)
        @total_projection = @results.sum { |row| row.projected_transfer.to_f }
        @teams = scoped_care_teams.order(:name)
      end
    end
  end
end

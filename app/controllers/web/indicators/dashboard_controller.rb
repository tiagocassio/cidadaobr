# frozen_string_literal: true

module Web
  module Indicators
    class DashboardController < BaseController
      before_action :require_facility_or_municipality!

      def show
        @quadrimester = resolve_quadrimester_param
        @catalog = IndicatorCatalog.where(active: true).order(:display_order)
        @team_results = scoped_team_indicator_results.where(quadrimester: @quadrimester).includes(:care_team)
        @scores_by_indicator = average_scores(@team_results)
        @open_gaps_count = scoped_citizen_indicator_gaps.where(status: "open").count
        @scored_count = @scores_by_indicator.count { |_, score| score.to_f >= 85.0 }
        @teams = scoped_care_teams.order(:name)
      end

      private

      def average_scores(results)
        grouped = results.group_by(&:indicator_code)
        grouped.transform_values do |rows|
          values = rows.filter_map { |row| row.score&.to_f }
          next 0.0 if values.empty?

          (values.sum / values.size).round(2)
        end
      end
    end
  end
end

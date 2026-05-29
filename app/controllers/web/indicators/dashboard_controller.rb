# frozen_string_literal: true

module Web
  module Indicators
    class DashboardController < BaseController
      before_action :require_facility_or_municipality!

      def show
        @quadrimester = resolve_quadrimester_param
        @catalog = IndicatorCatalog.active_portaria.order(:display_order)
        @team_results = scoped_team_indicator_results.where(quadrimester: @quadrimester).includes(:care_team)
        @scores_by_indicator = average_scores(@team_results)
        active_codes = IndicatorCatalog.active_portaria.select(:code)
        @open_gaps_count = scoped_citizen_indicator_gaps.where(status: "open", indicator_code: active_codes).count
        @catalog_total = @catalog.count
        @evaluated_indicator_count = @scores_by_indicator.size
        @scored_count = @scores_by_indicator.count { |_, score| score.to_f >= 85.0 }
        @teams = scoped_care_teams.order(:name)
        @team_average_scores = team_average_scores(@team_results)
        @ranked_teams = @teams.sort_by { |team| -(@team_average_scores[team.id] || 0) }
      end

      private

      def team_average_scores(results)
        results.group_by(&:care_team_id).transform_values do |rows|
          values = rows.filter_map { |row| row.score&.to_f }
          next nil if values.empty?

          (values.sum / values.size).round(2)
        end
      end

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

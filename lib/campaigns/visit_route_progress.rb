# frozen_string_literal: true

module Campaigns
  class VisitRouteProgress
    Summary = Data.define(:total_stops, :visited, :pending, :refused, :completion_pct)

    class << self
      def for_campaign(campaign:, route_date: nil)
        stops = VisitRouteStop.joins(:visit_route).where(visit_routes: { home_visit_campaign_id: campaign.id })
        stops = stops.where(visit_routes: { route_date: route_date }) if route_date.present?

        total = stops.count
        visited = stops.where(status: "visited").count
        pending = stops.where(status: "pending").count
        refused = stops.where(status: "refused").count
        pct = total.positive? ? ((visited.to_f / total) * 100).round(1) : 0.0

        Summary.new(total, visited, pending, refused, pct)
      end

      def by_team(campaign:, route_date: nil)
        scope = VisitRouteStop
          .joins(visit_route: :care_team)
          .where(visit_routes: { home_visit_campaign_id: campaign.id })
        scope = scope.where(visit_routes: { route_date: route_date }) if route_date.present?

        scope.group("care_teams.id", "care_teams.name")
          .pluck(
            "care_teams.id",
            "care_teams.name",
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(*) FILTER (WHERE visit_route_stops.status = 'visited')")
          )
          .map do |team_id, team_name, total, visited|
            {
              care_team_id: team_id,
              care_team_name: team_name,
              total_stops: total,
              visited_stops: visited,
              completion_pct: total.positive? ? ((visited.to_f / total) * 100).round(1) : 0.0
            }
          end
      end
    end
  end
end

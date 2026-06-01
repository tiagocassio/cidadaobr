# frozen_string_literal: true

module Routing
  # Groups targets by geographic proximity (PostGIS ST_ClusterDBSCAN) before route generation.
  class ClusterVisitRouteTargets
    DEFAULT_EPS_METERS = 800
    DEFAULT_MIN_POINTS = 1

    class << self
      def call(targets, eps_meters: DEFAULT_EPS_METERS, min_points: DEFAULT_MIN_POINTS)
        return { unlocated: [] } if targets.empty?
        return { unlocated: targets } if targets.size <= 1
        return { unlocated: targets } unless postgis_available?

        cluster_with_postgis(targets, eps_meters: eps_meters, min_points: min_points)
      end

      private

      def postgis_available?
        ActiveRecord::Base.connection.select_value("SELECT PostGIS_Version()").present?
      rescue StandardError
        false
      end

      def cluster_with_postgis(targets, eps_meters:, min_points:)
        indexed = targets.each_with_index.filter_map do |target, index|
          point = location_for(target)
          next unless point

          { target: target, index: index, lat: point[0], lng: point[1] }
        end
        return { unlocated: targets } if indexed.empty?

        values_sql = indexed.map do |row|
          Household.sanitize_sql_array(
            [ "(?, ?, ?::float, ?::float)", row[:index], row[:target].id, row[:lng], row[:lat] ]
          )
        end.join(", ")

        sql = <<~SQL.squish
          WITH points AS (
            SELECT * FROM (VALUES #{values_sql}) AS t(idx, target_id, lng, lat)
          ),
          clustered AS (
            SELECT idx, target_id,
              ST_ClusterDBSCAN(ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, #{eps_meters.to_f}, #{min_points.to_i})
                OVER () AS cluster_id
            FROM points
          )
          SELECT idx, cluster_id FROM clustered ORDER BY idx
        SQL

        rows = ActiveRecord::Base.connection.select_all(sql).to_a
        by_idx = rows.index_by { |row| row["idx"].to_i }
        by_cluster = Hash.new { |h, k| h[k] = [] }
        indexed.each do |row|
          cluster_id = by_idx[row[:index]]&.fetch("cluster_id", nil)
          if cluster_id.nil?
            by_cluster[:noise] << row[:target]
          else
            by_cluster[cluster_id] << row[:target]
          end
        end

        unclustered = targets - indexed.map { |row| row[:target] }
        by_cluster[:unlocated] = unclustered if unclustered.any?
        by_cluster
      end

      def location_for(target)
        household = target.household || target.citizen.household_members.order(:created_at).first&.household
        return unless household&.location

        [ household.location.y, household.location.x ]
      end
    end
  end
end

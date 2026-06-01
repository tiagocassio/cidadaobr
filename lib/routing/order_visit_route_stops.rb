# frozen_string_literal: true

module Routing
  class OrderVisitRouteStops
    class << self
      def call(targets, start_point: nil)
        return targets if targets.size <= 1

        distances = DistanceCache.new(targets, start_point: start_point)
        start = start_point || targets.filter_map { |target| distances.point_for(target) }.first
        ordered = order_nearest_neighbor(targets, start_point: start, distances: distances)
        improve_with_two_opt(ordered, start_point: start, distances: distances)
      end

      private

      def order_nearest_neighbor(targets, start_point:, distances:)
        remaining = targets.dup
        current = start_point
        ordered = []
        until remaining.empty?
          next_target = remaining.min_by { |target| distances.from_point(current, target) }
          ordered << next_target
          remaining.delete(next_target)
          current = distances.point_for(next_target) || current
        end

        ordered
      end

      def improve_with_two_opt(ordered, start_point:, distances:)
        return ordered if ordered.size < 4

        route = ordered.dup
        improved = true
        while improved
          improved = false
          (0...(route.size - 2)).each do |i|
            ((i + 2)...route.size).each do |j|
              delta = two_opt_delta(route, i, j, start_point: start_point, distances: distances)
              next unless delta.negative?

              route[(i + 1)..j] = route[(i + 1)..j].reverse
              improved = true
            end
          end
        end
        route
      end

      def two_opt_delta(route, i, j, start_point:, distances:)
        a = point_before(route, i, start_point, distances: distances)
        b = distances.point_for(route[i])
        c = distances.point_for(route[i + 1])
        d = distances.point_for(route[j])
        e = j + 1 < route.size ? distances.point_for(route[j + 1]) : nil
        return 0.0 unless a && b && c && d

        before = distances.between_points(a, b) + distances.between_points(c, d) + (e ? distances.between_points(d, e) : 0.0)
        after = distances.between_points(a, c) + distances.between_points(b, d) + (e ? distances.between_points(b, e) : 0.0)
        after - before
      end

      def point_before(route, index, start_point, distances:)
        return start_point if index.zero?

        distances.point_for(route[index - 1])
      end

      class DistanceCache
        def initialize(targets, start_point: nil)
          @start_point = start_point
          @points = targets.index_with { |target| location_for(target) }
          @cache = {}
          @postgis = postgis_available?
        end

        def point_for(target)
          @points[target]
        end

        def from_point(origin, target)
          point = point_for(target)
          return Float::INFINITY unless point && origin

          between_points(origin, point)
        end

        def between_points(from, to)
          return Float::INFINITY unless from && to

          key = [ from[0], from[1], to[0], to[1] ]
          @cache[key] ||= compute_distance(from, to)
        end

        private

        def postgis_available?
          ActiveRecord::Base.connection.select_value("SELECT PostGIS_Version()").present?
        rescue StandardError
          false
        end

        def compute_distance(from, to)
          if @postgis
            Household.connection.select_value(
              Household.sanitize_sql_array(
                [
                  "SELECT ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
                  from[1], from[0], to[1], to[0]
                ]
              )
            ).to_f
          else
            haversine_km(from, to) * 1000.0
          end
        end

        def location_for(target)
          household = target.household || target.citizen.household_members.order(:created_at).first&.household
          return unless household&.location

          [ household.location.y, household.location.x ]
        end

        def haversine_km(a, b)
          lat1, lon1 = a
          lat2, lon2 = b
          rad = Math::PI / 180.0
          dlat = (lat2 - lat1) * rad
          dlon = (lon2 - lon1) * rad
          lat1 *= rad
          lat2 *= rad
          h = Math.sin(dlat / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlon / 2)**2
          6371.0 * 2 * Math.asin(Math.sqrt(h))
        end
      end
    end
  end
end

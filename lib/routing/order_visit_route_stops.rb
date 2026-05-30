# frozen_string_literal: true

module Routing
  class OrderVisitRouteStops
    class << self
      def call(targets)
        return targets if targets.size <= 1

        if postgis_available?
          order_with_postgis(targets)
        else
          order_with_haversine(targets)
        end
      end

      private

      def postgis_available?
        ActiveRecord::Base.connection.select_value("SELECT PostGIS_Version()").present?
      rescue StandardError
        false
      end

      def order_with_postgis(targets)
        remaining = targets.dup
        ordered = [ remaining.shift ]
        current = location_for(ordered.last)

        until remaining.empty?
          next_target = remaining.min_by do |target|
            point = location_for(target)
            next Float::INFINITY unless point && current

            lat, lng = point
            Household.connection.select_value(
              Household.sanitize_sql_array(
                [
                  "SELECT ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
                  current[1], current[0], lng, lat
                ]
              )
            ).to_f
          end
          ordered << next_target
          remaining.delete(next_target)
          current = location_for(next_target) || current
        end

        ordered
      end

      def order_with_haversine(targets)
        remaining = targets.dup
        ordered = [ remaining.shift ]
        current_point = location_for(ordered.last)

        until remaining.empty?
          next_target = remaining.min_by do |target|
            point = location_for(target)
            point && current_point ? haversine_km(current_point, point) : Float::INFINITY
          end
          ordered << next_target
          remaining.delete(next_target)
          current_point = location_for(next_target) || current_point
        end

        ordered
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

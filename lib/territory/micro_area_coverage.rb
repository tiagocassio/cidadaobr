# frozen_string_literal: true

module Territory
  class MicroAreaCoverage
    class << self
      def apply!(micro_area:, remove_coverage:, coverage_bbox:)
        if remove_coverage
          micro_area.coverage = nil
          return :ok
        end

        return :skipped if coverage_bbox.nil?

        if coverage_bbox == :invalid
          micro_area.errors.add(:base, :invalid_coverage)
          return :invalid
        end

        micro_area.coverage = coverage_bbox
        :ok
      end

      def build_polygon(sw_lat:, sw_lng:, ne_lat:, ne_lng:)
        Cidadaobr::GeoPoint.bbox_polygon(
          sw_lat: sw_lat,
          sw_lng: sw_lng,
          ne_lat: ne_lat,
          ne_lng: ne_lng
        ) || :invalid
      end
    end
  end
end

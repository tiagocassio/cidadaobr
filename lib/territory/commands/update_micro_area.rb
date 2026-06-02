# frozen_string_literal: true

module Territory
  module Commands
    class UpdateMicroArea < ApplicationCommand
      Result = Data.define(:success, :micro_area)

      def initialize(micro_area:, attributes:, coverage_bbox:, remove_coverage:, health_facility_ids:)
        @micro_area = micro_area
        @attributes = attributes
        @coverage_bbox = coverage_bbox
        @remove_coverage = remove_coverage
        @health_facility_ids = health_facility_ids
      end

      def call
        apply_coverage!

        return Result.new(success: false, micro_area: @micro_area) unless @micro_area.errors.none? && @micro_area.update(@attributes)

        @micro_area.sync_health_facility_coverages!(@health_facility_ids)
        Result.new(success: true, micro_area: @micro_area)
      end

      private

      def apply_coverage!
        Territory::MicroAreaCoverage.apply!(
          micro_area: @micro_area,
          remove_coverage: @remove_coverage,
          coverage_bbox: @coverage_bbox
        )
      end
    end
  end
end

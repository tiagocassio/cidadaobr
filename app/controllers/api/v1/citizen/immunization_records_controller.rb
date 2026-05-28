# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class ImmunizationRecordsController < BaseController
        def index
          @records = CitizenImmunizationRecord.where(citizen_id: current_citizen.id).order(applied_on: :desc)
          @applied_records_percent = applied_records_percent
        end

        private

        # Share of projected wallet rows that already have an application date (not national schedule coverage).
        def applied_records_percent
          total, applied = @records.unscope(:order).pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(applied_on)")
          )
          return 0 if total.to_i.zero?

          ((applied.to_f / total) * 100).round
        end
      end
    end
  end
end

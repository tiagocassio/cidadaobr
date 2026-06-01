# frozen_string_literal: true

module Indicators
  module DslV1
    module VaccinationCalendar
      # PNI proxy schedule for children 0–24 months (onda 2 C2.E).
      REQUIRED_BY_MAX_AGE_MONTHS = {
        2 => %w[BCG HEPB],
        4 => %w[PENTA VIP],
        6 => %w[PENTA VIP],
        12 => %w[PENTA VIP],
        24 => %w[PENTA VIP MMR]
      }.freeze

      module_function

      def required_immunobiologics(age_months)
        REQUIRED_BY_MAX_AGE_MONTHS
          .select { |deadline, _| age_months >= deadline }
          .values
          .flatten
          .uniq
      end
    end
  end
end

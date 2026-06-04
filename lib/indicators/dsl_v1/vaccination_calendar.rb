# frozen_string_literal: true

module Indicators
  module DslV1
    module VaccinationCalendar
      module_function

      def required_immunobiologicals(age_months, reference_date: Date.current)
        PniScheduleEvaluator.required_immunobiologicals(age_months, reference_date: reference_date)
      end
    end
  end
end

# frozen_string_literal: true

module Scheduling
  module ErrorMessages
    module_function

    def slot_unavailable_message(error)
      code = error.code
      if code && Scheduling::Errors::SlotUnavailableError::CODES.key?(code)
        I18n.t("cidadaobr.scheduling.slot_unavailable.#{code}")
      else
        I18n.t("cidadaobr.scheduling.slot_unavailable.generic")
      end
    end
  end
end

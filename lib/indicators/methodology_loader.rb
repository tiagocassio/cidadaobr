# frozen_string_literal: true

module Indicators
  module MethodologyLoader
    PACK_DIR = Rails.root.join("db/methodology/3493-2024").freeze

    module_function

    def load(code)
      path = PACK_DIR.join("#{code}.json")
      return nil unless path.exist?

      JSON.parse(path.read)
    end

    def merge_into_expression(expression, code:)
      pack = load(code)
      return expression if pack.blank?

      expression.merge(
        "source_ref" => pack["source_ref"],
        "methodology_summary" => pack.slice("numerator_summary", "denominator_summary", "record_types")
      )
    end
  end
end

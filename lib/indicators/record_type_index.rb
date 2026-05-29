# frozen_string_literal: true

module Indicators
  module RecordTypeIndex
    BY_RECORD_TYPE = {
      "FCI" => %w[V_CAD C4 C5 C3 C6 C7],
      "FAI" => %w[C4 C5 C3 C6 C7 V_ACOMP M1],
      "FAD" => %w[V_ACOMP C6],
      "FP" => %w[C4 C5 C7],
      "FAO" => %w[B1 B2 B3 B4 B5 B6 M1],
      "FAC" => %w[B4 M1 M2],
      "FCC" => %w[M2],
      "FV" => %w[C6]
    }.freeze

    module_function

    def indicator_codes_for(record_type)
      BY_RECORD_TYPE.fetch(record_type.to_s, [])
    end
  end
end

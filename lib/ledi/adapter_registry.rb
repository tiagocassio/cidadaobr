# frozen_string_literal: true

module Ledi
  class AdapterRegistry
    ADAPTER_CLASSES = {
      "FCI" => Adapters::FciAdapter,
      "FCD" => Adapters::FcdAdapter,
      "FAI" => Adapters::FaiAdapter,
      "FAO" => Adapters::FaoAdapter,
      "FAC" => Adapters::FacAdapter,
      "FP" => Adapters::FpAdapter,
      "FV" => Adapters::FvAdapter,
      "FVD" => Adapters::FvdAdapter,
      "FAD" => Adapters::FadAdapter,
      "FAE" => Adapters::FaeAdapter,
      "FCZM" => Adapters::FczmAdapter,
      "FCC" => Adapters::FccAdapter,
      "MCA" => Adapters::McaAdapter
    }.freeze

    class << self
      def fetch(record_type)
        adapter_class = ADAPTER_CLASSES.fetch(record_type.to_s.upcase)
        type_entry = SerializedType.find_by_record_type!(record_type)
        adapter_class.new(type_entry)
      end
    end
  end
end

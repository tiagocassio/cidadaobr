# frozen_string_literal: true

module Ledi
  module BatchPayloadPack
    module_function

    def pack(records)
      records.sort_by { |record| [ record.created_at, record.id ] }.map(&:payload_binary).join
    end
  end
end

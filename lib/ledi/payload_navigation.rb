# frozen_string_literal: true

module Ledi
  # LEDI payload section traversal. Delegates to indicator resolvers until moved here.
  module PayloadNavigation
    module_function

    def each_section(payload, record_type: nil, &block)
      Indicators::DslV1::Resolvers::PayloadSections.each_section(payload, record_type: record_type, &block)
    end

    def dig(payload, path)
      Indicators::DslV1::Resolvers::PayloadSections.dig(payload, path)
    end
  end
end

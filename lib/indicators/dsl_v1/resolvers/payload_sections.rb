# frozen_string_literal: true

module Indicators
  module DslV1
    module Resolvers
      module PayloadSections
        module_function

        def each_section(payload, record_type: nil)
          return enum_for(:each_section, payload, record_type: record_type) unless block_given?

          yield payload if payload.is_a?(Hash)

          keys = nested_keys_for(record_type)
          keys.each do |key|
            Array(payload[key]).each { |section| yield section if section.is_a?(Hash) }
          end
        end

        def nested_keys_for(record_type)
          return LediPayloadPaths::NESTED_ATTENDANCE_KEYS.values.flatten.uniq if record_type.blank?

          LediPayloadPaths::NESTED_ATTENDANCE_KEYS.fetch(record_type.to_s, [])
        end

        def dig(payload, path)
          path.to_s.split(".").reduce(payload) do |current, segment|
            break nil if current.nil?

            current[segment] || current[segment.camelize(:lower)] || current[segment.camelize]
          end
        end

        def deep_values(object)
          case object
          when Hash
            object.values.flat_map { |value| deep_values(value) }
          when Array
            object.flat_map { |value| deep_values(value) }
          else
            [ object ]
          end
        end

        def list_includes?(payload, field_aliases, expected_values)
          normalized_expected = Array(expected_values).map(&:to_s)
          field_aliases.any? do |field|
            each_section(payload).any? do |section|
              values = Array(dig(section, field))
              values.map(&:to_s).intersect?(normalized_expected)
            end
          end
        end

        def procedure_matches_prefixes?(payload, prefixes)
          normalized_prefixes = Array(prefixes).map { |p| p.to_s.gsub(/\D/, "") }
          deep_values(payload).any? do |value|
            digits = value.to_s.gsub(/\D/, "")
            next false if digits.length < 6

            normalized_prefixes.any? { |prefix| digits.start_with?(prefix) }
          end
        end
      end
    end
  end
end

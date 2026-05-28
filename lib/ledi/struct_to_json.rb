# frozen_string_literal: true

module Ledi
  module StructToJson
    module_function

    def convert(value)
      case value
      when ::Thrift::Struct
        result = {}
        value.each_field do |_fid, field_info|
          name = field_info[:name]
          nested = value.send(name)
          next if nested.nil?

          result[camel_to_snake(name)] = convert(nested)
        end
        result
      when Array
        value.map { |item| convert(item) }
      when Hash
        value.transform_values { |item| convert(item) }
      else
        value
      end
    end

    def camel_to_snake(key)
      key.to_s
        .gsub("::", "_")
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr("-", "_")
        .downcase
    end
  end
end

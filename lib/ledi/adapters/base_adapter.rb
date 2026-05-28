# frozen_string_literal: true

module Ledi
  module Adapters
    class BaseAdapter
      def initialize(type_entry)
        @type_entry = type_entry
      end

      def deserialize(inner_binary)
        if @type_entry.master_child?
          deserialize_master_child(inner_binary)
        else
          struct = ThriftReader.read(inner_binary, @type_entry.resolve_thrift_class)
          { role: "record", payload: StructToJson.convert(struct) }
        end
      end

      private

      def deserialize_master_child(inner_binary)
        %w[master child].each do |role|
          thrift_class = @type_entry.resolve_thrift_class(role: role)
          struct = ThriftReader.read(inner_binary, thrift_class)
          return { role: role, payload: StructToJson.convert(struct) }
        rescue ::Thrift::ProtocolException
          next
        end

        raise SerializedType::UnknownTypeError, "Unable to deserialize master/child payload for #{@type_entry.record_type}"
      end
    end
  end
end

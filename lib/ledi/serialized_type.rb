# frozen_string_literal: true

module Ledi
  RecordType = Data.define(:code, :record_type, :archetype, :thrift_class, :thrift_classes) do
    def master_child?
      archetype == "master_child"
    end

    def monolithic?
      archetype == "monolithic"
    end

    def evolution?
      archetype == "evolution"
    end

    def resolve_thrift_class(role: nil)
      return constantize(thrift_class) if thrift_class.present?

      key = role.to_s
      class_name = thrift_classes[key] || thrift_classes[key.to_sym]
      constantize(class_name)
    end

    private

    def constantize(class_name)
      class_name.constantize
    end
  end

  class SerializedType
    class UnknownTypeError < StandardError; end

    class << self
      def all
        @all ||= config.fetch(:serialized_types).transform_keys(&:to_i).map do |code, entry|
          RecordType.new(
            code: code,
            record_type: entry.fetch(:record_type),
            archetype: entry.fetch(:archetype),
            thrift_class: entry[:thrift_class],
            thrift_classes: entry[:thrift_classes]
          )
        end
      end

      def find!(code)
        find(code) || raise(UnknownTypeError, "Unknown serialized type #{code}")
      end

      def find(code)
        index[code.to_i]
      end

      def find_by_record_type!(record_type)
        all.find { |entry| entry.record_type == record_type.to_s.upcase } ||
          raise(UnknownTypeError, "Unknown record type #{record_type}")
      end

      def config
        Rails.application.config.ledi
      end

      private

      def index
        @index ||= all.index_by(&:code)
      end
    end
  end
end

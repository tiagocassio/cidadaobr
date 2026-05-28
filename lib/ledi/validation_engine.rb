# frozen_string_literal: true

module Ledi
  class ValidationEngine
    Result = Data.define(:valid, :errors)

    class << self
      def call(clinical_record:)
        rules = LediValidationRule.where(record_type: clinical_record.record_type, ledi_version: clinical_record.payload_schema_version)
        errors = []

        rules.find_each do |rule|
          next if evaluate(rule.expression, clinical_record.payload_json, rule_code: rule.rule_code)

          errors << {
            code: rule.rule_code,
            field_path: error_field_path(rule.expression),
            message: rule.expression["message"] || rule.rule_code
          }
        end

        Result.new(valid: errors.empty?, errors: errors)
      end

      private

      def evaluate(expression, payload, rule_code: nil)
        case expression["type"]
        when "present"
          dig(payload, expression["field_path"]).present?
        when "equals"
          dig(payload, expression["field_path"]).to_s == expression["value"].to_s
        when "xor_present"
          fields = expression.fetch("fields")
          fields.count { |field| dig(payload, field).present? } == 1
        when "absent_when"
          trigger = dig(payload, expression.fetch("when_field"))
          return true unless ActiveModel::Type::Boolean.new.cast(trigger)

          expression.fetch("absent_fields").all? { |field| dig(payload, field).blank? }
        else
          Rails.error.report(
            StandardError.new("Unknown LEDI validation rule type=#{expression['type']} code=#{rule_code}"),
            handled: true,
            severity: :warning,
            context: { rule_code: rule_code, rule_type: expression["type"] }
          )
          false
        end
      end

      def error_field_path(expression)
        expression["field_path"].presence ||
          Array(expression["fields"]).join(", ").presence ||
          expression["when_field"]
      end

      def dig(payload, path)
        path.to_s.split(".").reduce(payload) do |current, segment|
          break nil if current.nil?

          current[segment] || current[segment.camelize(:lower)] || current[segment.camelize]
        end
      end
    end
  end
end

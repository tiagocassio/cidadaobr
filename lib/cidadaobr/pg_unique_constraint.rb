# frozen_string_literal: true

module Cidadaobr
  module PgUniqueConstraint
    module_function

    def match?(error, constraint_name)
      cause = error.cause
      if defined?(PG) && cause.is_a?(PG::UniqueViolation)
        return cause.constraint == constraint_name
      end

      error.message.include?(constraint_name)
    end
  end
end

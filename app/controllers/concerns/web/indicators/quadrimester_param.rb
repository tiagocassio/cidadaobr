# frozen_string_literal: true

module Web
  module Indicators
    module QuadrimesterParam
      extend ActiveSupport::Concern

      private

      def resolve_quadrimester_param
        raw = params.permit(:quadrimester)[:quadrimester].presence
        return ::Indicators::Quadrimester.current if raw.blank?

        ::Indicators::Quadrimester.parse!(raw)
        raw
      rescue ArgumentError
        ::Indicators::Quadrimester.current
      end
    end
  end
end

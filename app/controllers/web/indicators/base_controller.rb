# frozen_string_literal: true

module Web
  module Indicators
    class BaseController < Web::BaseController
      include QuadrimesterParam

      helper_method :indicators_average_title_key, :indicators_score_title_key

      private

      def indicators_average_title_key
        municipality_scope? ? "municipal_average" : "scoped_average"
      end

      def indicators_score_title_key
        municipality_scope? ? "municipal_score" : "scoped_score"
      end
    end
  end
end

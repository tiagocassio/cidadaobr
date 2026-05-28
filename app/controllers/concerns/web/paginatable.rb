# frozen_string_literal: true

module Web
  module Paginatable
    extend ActiveSupport::Concern

    PAGE_SIZE = 50

    included do
      helper_method :current_page if respond_to?(:helper_method)
    end

    private

    def paginate(scope)
      scope.limit(PAGE_SIZE).offset((current_page - 1) * PAGE_SIZE)
    end

    def current_page
      page = params[:page].to_i
      page.positive? ? page : 1
    end
  end
end

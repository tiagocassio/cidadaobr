# frozen_string_literal: true

module Web
  # Thin helpers over ActionController::StrongParameters (Rails guides).
  # Prefer params.expect for flat scalar resources (Rails 8+); require + permit for nested *_attributes.
  module StrongParameters
    extend ActiveSupport::Concern

    private

    def require_permitted(key, *permit_list)
      params.require(key).permit(*permit_list)
    end

    def permit_optional(key, *permit_list)
      params.permit(key => permit_list)[key]
    end
  end
end

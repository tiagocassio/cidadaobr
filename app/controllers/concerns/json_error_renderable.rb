# frozen_string_literal: true

module JsonErrorRenderable
  extend ActiveSupport::Concern

  private

  def render_json_error(message, status:)
    render partial: "shared/error", locals: { error: message }, status: status, formats: :json
  end
end

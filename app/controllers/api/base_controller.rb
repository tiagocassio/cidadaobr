# frozen_string_literal: true

module Api
  class BaseController < Api::ApplicationController
    include TenantRlsRequestScope

    before_action :authenticate_api!

    rescue_from ActiveRecord::RecordNotFound do
      render_json_error("Not found", status: :not_found)
    end

    private

    attr_reader :current_user, :current_membership

    def authenticate_api!
      token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
      payload = JwtTokenService.decode(token)
      return render_json_error("Unauthorized", status: :unauthorized) unless payload

      @current_user = User.find_by(id: payload[:sub], active: true)
      @current_membership = @current_user&.active_membership_for(payload[:municipality_id])
      render_json_error("Unauthorized", status: :unauthorized) unless @current_user && @current_membership
    end
  end
end

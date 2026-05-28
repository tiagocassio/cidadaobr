# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include Authenticatable

    before_action :authenticate_api!

    private

    def authenticate_api!
      token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
      payload = JwtTokenService.decode(token)
      return render json: { error: "Unauthorized" }, status: :unauthorized unless payload

      @current_user = User.find_by(id: payload[:sub], active: true)
      @current_membership = @current_user&.active_membership_for(payload[:municipality_id])
      render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user && @current_membership
    end
  end
end

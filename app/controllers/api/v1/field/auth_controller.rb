# frozen_string_literal: true

module Api
  module V1
    module Field
      class AuthController < ActionController::API
        def create
          user = User.find_by(email: params[:email]&.downcase)
          membership = user&.active_membership_for(params[:municipality_id])

          if user&.authenticate(params[:password]) && membership
            render json: {
              token: JwtTokenService.encode(user: user, membership: membership),
              scope: membership.scope,
              municipality_id: membership.municipality_id,
              health_facility_id: membership.health_facility_id
            }
          else
            render json: { error: "Invalid credentials" }, status: :unauthorized
          end
        end
      end
    end
  end
end

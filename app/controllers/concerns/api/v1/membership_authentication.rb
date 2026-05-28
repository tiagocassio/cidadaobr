# frozen_string_literal: true

module Api
  module V1
    module MembershipAuthentication
      extend ActiveSupport::Concern

      def create
        user = User.find_by(email: params[:email]&.downcase)
        membership = user&.active_membership_for(params[:municipality_id])

        if user&.authenticate(params[:password]) && membership
          @token = JwtTokenService.encode(user: user, membership: membership)
          @membership = membership
          render "api/v1/auth/create"
        else
          render_json_error("Invalid credentials", status: :unauthorized)
        end
      end
    end
  end
end

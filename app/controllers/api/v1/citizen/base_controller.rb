# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class BaseController < Api::ApplicationController
        prepend_before_action :authenticate_citizen!
        around_action :with_citizen_tenant_context

        rescue_from ActiveRecord::RecordNotFound do
          render_json_error("Not found", status: :not_found)
        end

        private

        attr_reader :current_citizen_account, :current_citizen, :citizen_auth_payload

        def with_citizen_tenant_context
          scope = Cidadaobr::TenantScope.from_citizen_account(current_citizen_account)
          Cidadaobr::TenantContext.with(scope) { yield }
        end

        def authenticate_citizen!
          token = bearer_token
          @citizen_auth_payload = JwtTokenService.decode(token)
          return render_json_error("Unauthorized", status: :unauthorized) unless citizen_auth_payload&.dig(:scope) == "citizen"

          auth_scope = Cidadaobr::TenantScope.new(
            municipality_id: citizen_auth_payload[:municipality_id],
            scope: "municipality",
            health_facility_id: nil,
            team_ids: [],
            citizen_id: nil
          )

          Cidadaobr::TenantContext.with(auth_scope) do
            @current_citizen_account = CitizenAccount.find_by(
              id: citizen_auth_payload[:account_id],
              active: true,
              citizen_id: citizen_auth_payload[:citizen_id]
            )
            @current_citizen = @current_citizen_account&.citizen
          end

          render_json_error("Unauthorized", status: :unauthorized) unless @current_citizen_account && @current_citizen
        end

        def bearer_token
          request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
        end
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    module Citizen
      class AuthController < Api::ApplicationController
        UUID_PATTERN = /\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i

        def create
          municipality_id = params.require(:municipality_id)
          unless municipality_id.to_s.match?(UUID_PATTERN)
            return render_json_error("Invalid municipality_id", status: :unprocessable_entity)
          end

          rate_limit_key = "#{request.remote_ip}:#{municipality_id}"
          if Cidadaobr::AuthRateLimiter.blocked?(scope: "citizen_auth", key: rate_limit_key)
            return render_json_error("Too many login attempts", status: :too_many_requests)
          end

          cpf = normalized_cpf
          unless Cidadaobr::Cpf.valid?(cpf)
            register_failed_attempt!(rate_limit_key)
            return render_json_error("Invalid credentials", status: :unauthorized)
          end

          scope = Cidadaobr::TenantScope.new(
            municipality_id: municipality_id,
            scope: "municipality",
            health_facility_id: nil,
            team_ids: [],
            citizen_id: nil
          )

          account = Cidadaobr::TenantContext.with(scope) do
            CitizenAccount.find_by(
              municipality_id: municipality_id,
              cpf: cpf,
              active: true
            )
          end

          if account&.authenticate(params[:password])
            Cidadaobr::AuthRateLimiter.clear_key!(scope: "citizen_auth", key: rate_limit_key)
            @token = JwtTokenService.encode_citizen(account: account)
            @citizen_account = account
            render :create
          else
            register_failed_attempt!(rate_limit_key)
            render_json_error("Invalid credentials", status: :unauthorized)
          end
        end

        private

        def register_failed_attempt!(rate_limit_key)
          Cidadaobr::AuthRateLimiter.record_failure!(scope: "citizen_auth", key: rate_limit_key)
        end

        def normalized_cpf
          params[:cpf].to_s.gsub(/\D/, "")
        end
      end
    end
  end
end

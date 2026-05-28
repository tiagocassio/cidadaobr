# frozen_string_literal: true

class TenantScopeMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    tenant = tenant_from_request(request)

    if tenant
      Cidadaobr::TenantContext.with(tenant) do
        @app.call(env)
      end
    else
      @app.call(env)
    end
  end

  private

  def tenant_from_request(request)
    if request.session[:tenant].present?
      return tenant_from_session(request.session[:tenant])
    end

    token = bearer_token(request)
    return unless token

    payload = JwtTokenService.decode(token)
    return unless payload

    Cidadaobr::TenantScope.new(
      municipality_id: payload[:municipality_id],
      scope: payload[:scope],
      health_facility_id: payload[:health_facility_id],
      team_ids: Array(payload[:team_ids]),
      citizen_id: payload[:citizen_id]
    )
  end

  def tenant_from_session(data)
    Cidadaobr::TenantScope.new(
      municipality_id: data["municipality_id"],
      scope: data["scope"],
      health_facility_id: data["health_facility_id"],
      team_ids: data["team_ids"] || [],
      citizen_id: data["citizen_id"]
    )
  end

  def bearer_token(request)
    header = request.headers["Authorization"]
    return unless header&.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip
  end
end

# frozen_string_literal: true

# Session SET (apply!) for reads; SET LOCAL (apply_local!) for writes inside AR transactions.
# See TenantRls, TenantContext, and config/initializers/tenant_rls_transaction.rb.
module Cidadaobr
  module TenantScopeConnection
    TENANT_SETTINGS = %w[
      app.current_municipality_id
      app.current_scope
      app.current_health_facility_id
      app.current_team_ids
      app.current_citizen_id
    ].freeze

    module_function

    # Session-level variables for the current connection (web request / job).
    # Pair with clear! when the scope ends so pooled connections do not leak context.
    def apply!(tenant)
      connection = ActiveRecord::Base.connection
      connection.execute("SET app.current_municipality_id = #{connection.quote(tenant.municipality_id)}")
      connection.execute("SET app.current_scope = #{connection.quote(tenant.scope)}")
      connection.execute("SET app.current_health_facility_id = #{connection.quote(tenant.health_facility_id || '')}")
      connection.execute("SET app.current_team_ids = #{connection.quote(tenant.team_ids.join(','))}")
      connection.execute("SET app.current_citizen_id = #{connection.quote(tenant.citizen_id || '')}")
    end

    # Transaction-scoped variables for writes inside ActiveRecord::Base.transaction.
    def apply_local!(tenant)
      connection = ActiveRecord::Base.connection
      connection.execute("SET LOCAL app.current_municipality_id = #{connection.quote(tenant.municipality_id)}")
      connection.execute("SET LOCAL app.current_scope = #{connection.quote(tenant.scope)}")
      connection.execute("SET LOCAL app.current_health_facility_id = #{connection.quote(tenant.health_facility_id || '')}")
      connection.execute("SET LOCAL app.current_team_ids = #{connection.quote(tenant.team_ids.join(','))}")
      connection.execute("SET LOCAL app.current_citizen_id = #{connection.quote(tenant.citizen_id || '')}")
    end

    def clear!
      connection = ActiveRecord::Base.connection
      TENANT_SETTINGS.each do |setting|
        connection.execute("RESET #{setting}")
      rescue ActiveRecord::StatementInvalid
        nil
      end
    end
  end
end

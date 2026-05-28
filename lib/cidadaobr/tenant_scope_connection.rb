# frozen_string_literal: true

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

    def apply!(tenant)
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

# frozen_string_literal: true

module Cidadaobr
  # Helpers for PostgreSQL RLS session variables (app.current_*).
  module TenantRls
    module_function

    # Session-level scope for reads (whole request/job connection).
    def apply_read_scope!(tenant: TenantContext.current)
      raise Cidadaobr::Errors::MissingTenantScope, "Tenant scope is required" unless tenant

      TenantScopeConnection.apply!(tenant)
    end

    # Same-transaction scope for INSERT/UPDATE (RLS WITH CHECK).
    def apply_write_scope!(tenant: TenantContext.current_or_raise!)
      TenantScopeConnection.apply_local!(tenant)
    end

    def write_transaction(tenant: TenantContext.current_or_raise!, **options, &block)
      ActiveRecord::Base.connection.transaction(**options) do
        apply_write_scope!(tenant: tenant)
        yield
      end
    end
  end
end

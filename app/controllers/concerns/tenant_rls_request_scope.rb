# frozen_string_literal: true

# Re-applies session-level RLS variables at the start of each controller action.
# Middleware already sets tenant once; this covers reads after nested write transactions.
module TenantRlsRequestScope
  extend ActiveSupport::Concern

  included do
    around_action :apply_request_tenant_rls_scope
  end

  private

  def apply_request_tenant_rls_scope
    tenant = Cidadaobr::TenantContext.current
    Cidadaobr::TenantRls.apply_read_scope!(tenant: tenant) if tenant
    yield
  end
end

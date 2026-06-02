# frozen_string_literal: true

class ApplicationCommand
  def self.call(**kwargs)
    new(**kwargs).call
  end

  # ADR-0006: explicit tenant write scope when TenantContext is set; otherwise plain AR transaction.
  def write_transaction(**options, &block)
    tenant = Cidadaobr::TenantContext.current
    if tenant
      Cidadaobr::TenantRls.write_transaction(tenant: tenant, **options, &block)
    else
      ActiveRecord::Base.transaction(**options, &block)
    end
  end
end

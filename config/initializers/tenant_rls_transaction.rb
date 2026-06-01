# frozen_string_literal: true

# When TenantContext is active, every AR transaction re-applies SET LOCAL app.current_*
# so RLS WITH CHECK passes on INSERT/UPDATE (including implicit transactions inside #save).
module TenantRlsTransactionExtension
  def transaction(*args, &block)
    options = args.extract_options!
    tenant = Cidadaobr::TenantContext.current

    if tenant && block_given? && !options.delete(:skip_tenant_rls)
      connection.transaction(*args, **options) do
        Cidadaobr::TenantScopeConnection.apply_local!(tenant)
        yield
      end
    else
      super(*args, **options, &block)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.prepend(TenantRlsTransactionExtension)
end

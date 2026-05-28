# frozen_string_literal: true

module Cidadaobr
  class TenantContext
    thread_mattr_accessor :current

    class << self
      def with(tenant, &block)
        previous = current
        self.current = tenant
        TenantScopeConnection.apply!(tenant)
        yield
      ensure
        self.current = previous
        if previous
          TenantScopeConnection.apply!(previous)
        else
          TenantScopeConnection.clear!
        end
      end

      def current_or_raise!
        current || raise(Errors::MissingTenantScope, "Tenant scope is required")
      end
    end
  end
end

# frozen_string_literal: true

module TenantHelpers
  def with_tenant(membership_or_scope)
    tenant =
      if membership_or_scope.is_a?(Cidadaobr::TenantScope)
        membership_or_scope
      else
        Cidadaobr::TenantScope.from_membership(membership_or_scope)
      end

    Cidadaobr::TenantContext.with(tenant) { yield tenant }
  end
end

RSpec.configure do |config|
  config.include TenantHelpers
end

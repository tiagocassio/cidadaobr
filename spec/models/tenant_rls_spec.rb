# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tenant RLS isolation", type: :model do
  let(:municipality) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality, name: "UBS A") }
  let(:facility_b) { create(:health_facility, municipality: municipality, name: "UBS B") }
  let(:membership_a) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility_a, scope: "facility")
  end
  let(:membership_b) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility_b, scope: "facility")
  end

  def record_event(membership, facility)
    with_tenant(Cidadaobr::TenantScope.from_membership(membership)) do
      CommandBus.dispatch(
        RecordPlatformEvent,
        event_type: "platform.bootstrapped",
        aggregate_type: "Platform",
        aggregate_id: SecureRandom.uuid,
        payload: { facility_id: facility.id },
        topic: "domain.outbox",
        metadata: {}
      )
    end
  end

  it "prevents cross-facility reads under facility scope" do
    record_event(membership_a, facility_a)
    record_event(membership_b, facility_b)

    visible_ids = with_tenant(Cidadaobr::TenantScope.from_membership(membership_a)) do
      DomainEvent.pluck(:health_facility_id)
    end

    expect(visible_ids).to all(eq(facility_a.id))
    expect(visible_ids).not_to include(facility_b.id)
  end
end

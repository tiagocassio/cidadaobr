# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tenant RLS transaction extension" do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "persists health facilities created inside TenantContext and lists them on the same connection" do
    Cidadaobr::TenantContext.with(
      Cidadaobr::TenantScope.new(
        municipality_id: municipality.id,
        scope: "municipality",
        health_facility_id: nil,
        team_ids: [],
        citizen_id: nil
      )
    ) do
      facility = nil
      ActiveRecord::Base.transaction do
        facility = HealthFacility.create!(
          municipality: municipality,
          name: "UBS RLS Patch",
          cnes: "8887776",
          facility_service_kind: "primary_care"
        )
      end

      expect(HealthFacility.find_by(id: facility.id)).to be_present
      expect(HealthFacility.pluck(:cnes)).to include("8887776")
    end
  end

  it "applies write scope inside nested command transactions" do
    Cidadaobr::TenantContext.with(Cidadaobr::TenantScope.from_membership(membership)) do
      expect {
        RecordPlatformEvent.call(
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { probe: true },
          topic: "domain.outbox",
          metadata: {}
        )
      }.to change(DomainEvent, :count).by(1)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cidadaobr::TenantScope do
  describe ".from_envelope" do
    it "derives municipality scope when only municipality_id is present" do
      tenant = described_class.from_envelope(
        "municipality_id" => SecureRandom.uuid
      )

      expect(tenant.scope).to eq("municipality")
      expect(tenant.health_facility_id).to be_nil
      expect(tenant.team_ids).to eq([])
    end

    it "derives facility scope from health_facility_id" do
      facility_id = SecureRandom.uuid
      tenant = described_class.from_envelope(
        "municipality_id" => SecureRandom.uuid,
        "health_facility_id" => facility_id
      )

      expect(tenant.scope).to eq("facility")
      expect(tenant.health_facility_id).to eq(facility_id)
    end

    it "derives team scope from care_team_id" do
      team_id = SecureRandom.uuid
      tenant = described_class.from_envelope(
        "municipality_id" => SecureRandom.uuid,
        "health_facility_id" => SecureRandom.uuid,
        "care_team_id" => team_id
      )

      expect(tenant.scope).to eq("team")
      expect(tenant.team_ids).to eq([ team_id ])
    end
  end
end

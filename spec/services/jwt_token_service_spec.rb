# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtTokenService, type: :service do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:user) { create(:user) }
  let(:membership) do
    create(:user_municipality_membership, user: user, municipality: municipality, health_facility: facility, scope: "facility")
  end

  it "encodes and decodes tenant claims" do
    token = described_class.encode(user: user, membership: membership)
    payload = described_class.decode(token)

    expect(payload[:sub]).to eq(user.id)
    expect(payload[:municipality_id]).to eq(municipality.id)
    expect(payload[:scope]).to eq("facility")
    expect(payload[:health_facility_id]).to eq(facility.id)
  end
end

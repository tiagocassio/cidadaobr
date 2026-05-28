# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "#active_membership_for" do
    let(:municipality) { create(:municipality) }
    let(:facility) { create(:health_facility, municipality: municipality) }
    let(:user) { create(:user) }

    it "prefers facility scope over municipality scope" do
      municipality_membership = create(
        :user_municipality_membership,
        user: user,
        municipality: municipality,
        scope: "municipality",
        role_code: "municipal_admin"
      )
      facility_membership = create(
        :user_municipality_membership,
        user: user,
        municipality: municipality,
        health_facility: facility,
        scope: "facility",
        role_code: "community_agent"
      )

      expect(user.active_membership_for(municipality.id)).to eq(facility_membership)
      expect(user.active_membership_for(municipality.id)).not_to eq(municipality_membership)
    end

    it "prefers team scope over facility scope" do
      facility_membership = create(
        :user_municipality_membership,
        user: user,
        municipality: municipality,
        health_facility: facility,
        scope: "facility",
        role_code: "community_agent"
      )
      team_membership = create(
        :user_municipality_membership,
        user: user,
        municipality: municipality,
        scope: "team",
        role_code: "community_agent"
      )

      expect(user.active_membership_for(municipality.id)).to eq(team_membership)
      expect(user.active_membership_for(municipality.id)).not_to eq(facility_membership)
    end
  end
end

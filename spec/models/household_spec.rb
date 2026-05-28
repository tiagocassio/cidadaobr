# frozen_string_literal: true

require "rails_helper"

RSpec.describe Household do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  describe ".within_radius" do
    it "returns households near a point in meters" do
      center = Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
      nearby = Cidadaobr::GeoPoint.build(lng: -46.6330, lat: -23.5505)
      far = Cidadaobr::GeoPoint.build(lng: -46.0, lat: -23.0)

      with_tenant(membership) do
        near_household = Household.create!(
          municipality: municipality,
          health_facility: facility,
          ibge_code: municipality.ibge_code,
          location: nearby
        )
        Household.create!(
          municipality: municipality,
          health_facility: facility,
          ibge_code: municipality.ibge_code,
          location: far
        )

        results = Household.within_radius(center.x, center.y, 500)
        expect(results).to contain_exactly(near_household)
      end
    end
  end

  describe "#coordinates" do
    it "returns lat/lng hash" do
      household = Household.new(location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505))

      expect(household.coordinates).to eq(lat: -23.5505, lng: -46.6333)
    end
  end
end

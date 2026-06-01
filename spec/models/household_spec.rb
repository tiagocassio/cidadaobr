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

  describe ".within_micro_area" do
    it "counts households inside geographic coverage polygon" do
      team = create(:care_team, municipality: municipality, health_facility: facility)
      micro = create(:micro_area, municipality: municipality, care_team: team, code: "01")
      inside = Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
      outside = Cidadaobr::GeoPoint.build(lng: -46.0, lat: -23.0)

      with_tenant(membership) do
        in_household = Household.create!(
          municipality: municipality,
          health_facility: facility,
          ibge_code: municipality.ibge_code,
          street: "Dentro",
          location: inside
        )
        Household.create!(
          municipality: municipality,
          health_facility: facility,
          ibge_code: municipality.ibge_code,
          street: "Fora",
          location: outside
        )

        expect(Household.within_micro_area(micro)).to contain_exactly(in_household)
        expect(micro.located_households_count).to eq(1)
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

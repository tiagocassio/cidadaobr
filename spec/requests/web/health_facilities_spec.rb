# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web health facilities", type: :request do
  let(:municipality) { create(:municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:facility_membership) do
    create(:user_municipality_membership, user: create(:user), municipality: municipality, health_facility: facility, scope: "facility")
  end

  it "allows municipal admin to list and create facilities" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    get web_health_facilities_path
    expect(response).to have_http_status(:ok)

    expect {
      post web_health_facilities_path, params: {
        health_facility: { name: "UBS Teste", cnes: "7654321", facility_service_kind: "primary_care" }
      }
    }.to change {
      with_tenant(admin_membership) { HealthFacility.count }
    }.by(1)
  end

  it "stores optional coordinates on create" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    post web_health_facilities_path, params: {
      health_facility: {
        name: "UBS Geoloc",
        cnes: "7654322",
        facility_service_kind: "primary_care",
        latitude: -23.5505,
        longitude: -46.6333
      }
    }

    facility = with_tenant(admin_membership) { HealthFacility.find_by(cnes: "7654322") }
    expect(facility.location).to be_present
    expect(facility.coordinates).to include(lat: -23.5505, lng: -46.6333)
  end

  it "clears stored coordinates when latitude and longitude are blank" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)
    facility.update!(
      location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
    )

    patch web_health_facility_path(facility), params: {
      health_facility: {
        name: facility.name,
        cnes: facility.cnes,
        facility_service_kind: facility.facility_service_kind,
        latitude: "",
        longitude: ""
      }
    }

    expect(response).to redirect_to(web_health_facility_path(facility))
    expect(with_tenant(admin_membership) { facility.reload.location }).to be_nil
  end

  it "clears stored coordinates when only latitude is provided" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)
    facility.update!(
      location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
    )

    patch web_health_facility_path(facility), params: {
      health_facility: {
        name: facility.name,
        cnes: facility.cnes,
        facility_service_kind: facility.facility_service_kind,
        latitude: -23.5505,
        longitude: ""
      }
    }

    expect(with_tenant(admin_membership) { facility.reload.location }).to be_nil
  end

  it "rejects out-of-range coordinates" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    post web_health_facilities_path, params: {
      health_facility: {
        name: "UBS Invalid",
        cnes: "7654323",
        facility_service_kind: "primary_care",
        latitude: 51.5074,
        longitude: -0.1278
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(with_tenant(admin_membership) { HealthFacility.find_by(cnes: "7654323") }).to be_nil
  end

  it "blocks facility manager from managing facilities" do
    sign_in_web(user: facility_membership.user, membership: facility_membership)

    get web_health_facilities_path
    expect(response).to redirect_to(web_root_path)
  end

  it "allows municipal admin to view a facility" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    get web_health_facility_path(facility)

    expect(response).to have_http_status(:ok)
  end
end

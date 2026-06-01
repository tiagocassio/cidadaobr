# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web households", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:micro_area) { create(:micro_area, municipality: municipality, care_team: team, code: "01") }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before do
    sign_in_web(user: admin_membership.user, membership: admin_membership)
    micro_area
  end

  it "creates a household with micro-area" do
    expect {
      post web_households_path, params: {
        household: {
          street: "Rua A",
          street_number: "10",
          neighborhood: "Centro",
          postal_code: "01001000",
          micro_area_code: "01",
          property_type: 1,
          health_facility_id: facility.id,
          care_team_id: team.id,
          housing_conditions: { localizacao: 1, tipo_domicilio: 1, nu_moradores: "3" }
        }
      }
    }.to change { with_tenant(admin_membership) { Household.count } }.by(1)

    household = with_tenant(admin_membership) { Household.order(:created_at).last }
    expect(response).to redirect_to(web_household_path(household))
    expect(household.micro_area_code).to eq("01")
  end

  it "updates household micro-area" do
    household = with_tenant(admin_membership) do
      create(:household, municipality: municipality, health_facility: facility, care_team: team, micro_area_code: nil)
    end

    patch web_household_path(household), params: {
      household: {
        street: household.street,
        street_number: household.street_number,
        neighborhood: household.neighborhood || "Centro",
        postal_code: household.postal_code || "01001000",
        micro_area_code: "01",
        property_type: 1,
        health_facility_id: facility.id,
        care_team_id: team.id,
        housing_conditions: { localizacao: 1, tipo_domicilio: 1, nu_moradores: "3" }
      }
    }

    expect(response).to redirect_to(web_household_path(household))
    expect(with_tenant(admin_membership) { household.reload.micro_area_code }).to eq("01")
  end
end

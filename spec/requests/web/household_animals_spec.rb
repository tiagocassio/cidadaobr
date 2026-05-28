# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web household animals", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  let!(:household) do
    with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
      create(:household, municipality: municipality, health_facility: facility, care_team: team)
    end
  end

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  it "creates an animal on household" do
    expect {
      post web_household_household_animals_path(household), params: {
        household_animal: { species: "gato", quantity: 2 }
      }
    }.to change { with_tenant(admin_membership) { HouseholdAnimal.count } }.by(1)

    expect(response).to redirect_to(web_household_path(household))
  end

  it "destroys an animal" do
    animal = with_tenant(admin_membership) { create(:household_animal, household: household) }

    expect {
      delete web_household_animal_path(animal)
    }.to change { with_tenant(admin_membership) { HouseholdAnimal.count } }.by(-1)
  end
end

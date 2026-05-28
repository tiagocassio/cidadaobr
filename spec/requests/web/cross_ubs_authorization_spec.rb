# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web cross-UBS authorization", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality, name: "UBS A") }
  let(:facility_b) { create(:health_facility, municipality: municipality, name: "UBS B") }
  let(:team_b) { create(:care_team, municipality: municipality, health_facility: facility_b) }
  let(:facility_a_membership) do
    create(:user_municipality_membership, user: create(:user), municipality: municipality, health_facility: facility_a, scope: "facility")
  end
  let(:municipal_scope) do
    Cidadaobr::TenantScope.new(municipality_id: municipality.id, scope: "municipality", health_facility_id: nil, team_ids: [], citizen_id: nil)
  end

  let!(:citizen_b) do
    with_tenant(municipal_scope) do
      create(:citizen, municipality: municipality, health_facility: facility_b, care_team: team_b, cpf: "52998224725")
    end
  end

  let!(:household_b) do
    with_tenant(municipal_scope) do
      create(:household, municipality: municipality, health_facility: facility_b, care_team: team_b, street: "Rua B")
    end
  end

  let!(:ledi_batch_b) do
    with_tenant(municipal_scope) do
      create(:ledi_batch, municipality: municipality, health_facility: facility_b, batch_number: 99, status: "ready")
    end
  end

  before { sign_in_web(user: facility_a_membership.user, membership: facility_a_membership) }

  it "hides citizens from another facility" do
    get web_citizen_path(citizen_b)
    expect(response).to have_http_status(:not_found)
  end

  it "hides households from another facility" do
    get web_household_path(household_b)
    expect(response).to have_http_status(:not_found)
  end

  it "hides ledi batches from another facility" do
    get web_ledi_batch_path(ledi_batch_b)
    expect(response).to have_http_status(:not_found)
  end

  it "blocks facility managers from user administration" do
    get web_users_path
    expect(response).to redirect_to(web_root_path)
  end
end

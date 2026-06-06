# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web shared care cases", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality")
  end
  let(:citizen) do
    with_tenant(admin_membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end
  let(:shared_care_case) do
    with_tenant(admin_membership) do
      Ledi::CreateSharedCareCase.call(citizen_id: citizen.id, ciap2_code: "A01", clinical_summary: "FCC web")
    end
  end

  it "records an evolution via POST" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    expect {
      post record_evolution_web_shared_care_case_path(shared_care_case),
           params: { evolution_note: "Evolução via web" }
    }.to change {
      with_tenant(admin_membership) { shared_care_case.shared_care_evolutions.count }
    }.by(1)

    expect(response).to redirect_to(web_shared_care_case_path(shared_care_case))
  end

  it "creates a shared care case scoped to the tenant" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    expect {
      post web_shared_care_cases_path, params: {
        shared_care_case: {
          citizen_id: citizen.id,
          ciap2_code: "A01",
          clinical_summary: "Caso FCC piloto"
        }
      }
    }.to change {
      with_tenant(admin_membership) { SharedCareCase.count }
    }.by(1)

    created = with_tenant(admin_membership) { SharedCareCase.order(:created_at).last }
    expect(response).to redirect_to(web_shared_care_case_path(created))
  end
end

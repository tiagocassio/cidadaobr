# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Citizen immunization records API", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:tenant_scope) do
    Cidadaobr::TenantScope.new(municipality_id: municipality.id, scope: "municipality", health_facility_id: nil, team_ids: [], citizen_id: nil)
  end
  let(:citizen) do
    with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end
  let!(:account) do
    with_tenant(tenant_scope) do
      CitizenAccount.create!(municipality: municipality, citizen: citizen, cpf: citizen.cpf, password: "password123")
    end
  end
  let(:token) { JwtTokenService.encode_citizen(account: account) }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }

  before do
    with_tenant(tenant_scope) do
      CitizenImmunizationRecord.create!(
        municipality: municipality,
        citizen: citizen,
        vaccine_code: "BCG",
        vaccine_name: "BCG",
        dose_label: "D1",
        applied_on: Date.current
      )
    end
  end

  it "returns immunization wallet with coverage" do
    get "/api/v1/citizen/immunization_records", headers: auth_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.fetch("records")).not_to be_empty
    expect(body).to have_key("applied_records_percent")
  end
end

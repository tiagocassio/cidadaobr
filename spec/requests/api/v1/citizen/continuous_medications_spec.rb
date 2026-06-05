# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Citizen continuous medications API", type: :request do
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
  let(:headers) { { "Authorization" => "Bearer #{JwtTokenService.encode_citizen(account: account)}" } }

  it "registers a continuous medication" do
    post "/api/v1/citizen/continuous_medications",
         params: { medication_name: "Losartana", dosage: "50mg", frequency: "1x/dia" },
         headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("medication", "medication_name")).to eq("Losartana")

    citizen_scope = Cidadaobr::TenantScope.from_citizen_account(account)
    Cidadaobr::TenantContext.with(citizen_scope) do
      expect(OutboxMessage.where(event_type: Cidadaobr::KafkaTopics::CONTINUOUS_MEDICATION_REGISTERED).count).to eq(1)
    end
  end

  it "lists active continuous medications" do
    citizen_scope = Cidadaobr::TenantScope.from_citizen_account(account)
    with_tenant(citizen_scope) do
      CitizenContinuousMedication.create!(
        municipality: municipality,
        citizen: citizen,
        medication_name: "Losartana",
        active: true
      )
    end

    get "/api/v1/citizen/continuous_medications", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.size).to eq(1)
    expect(response.parsed_body.first["medication_name"]).to eq("Losartana")
  end

  it "returns unprocessable entity for invalid started_on" do
    post "/api/v1/citizen/continuous_medications",
         params: { medication_name: "Losartana", started_on: "invalid" },
         headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

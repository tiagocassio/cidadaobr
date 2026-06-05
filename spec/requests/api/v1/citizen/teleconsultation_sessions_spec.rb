# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Citizen teleconsultation sessions API", type: :request do
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

  it "creates a teleconsultation session" do
    post "/api/v1/citizen/teleconsultation_sessions",
         params: { scheduled_at: 1.day.from_now.iso8601 },
         headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("session", "status")).to eq("scheduled")

    citizen_scope = Cidadaobr::TenantScope.from_citizen_account(account)
    Cidadaobr::TenantContext.with(citizen_scope) do
      expect(OutboxMessage.where(event_type: Cidadaobr::KafkaTopics::TELECONSULTATION_SESSION_CREATED).count).to eq(1)
    end
  end

  it "lists teleconsultation sessions" do
    citizen_scope = Cidadaobr::TenantScope.from_citizen_account(account)
    with_tenant(citizen_scope) do
      TeleconsultationSession.create!(
        municipality: municipality,
        citizen: citizen,
        scheduled_at: 1.day.from_now,
        room_token: "token",
        status: "scheduled"
      )
    end

    get "/api/v1/citizen/teleconsultation_sessions", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.size).to eq(1)
  end

  it "returns unprocessable entity for invalid scheduled_at" do
    post "/api/v1/citizen/teleconsultation_sessions",
         params: { scheduled_at: "not-a-date" },
         headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns unprocessable entity when appointment belongs to another citizen" do
    other_citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, cpf: "52998224725")
    end
    appointment = with_tenant(tenant_scope) do
      room = ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala FCC Tele")
      service_type = AppointmentServiceType.create!(municipality: municipality, name: "Consulta", code: "CONS")
      Appointment.create!(
        municipality: municipality,
        citizen: other_citizen,
        health_facility: facility,
        care_team: team,
        consultation_room: room,
        appointment_service_type: service_type,
        scheduled_at: 1.day.from_now,
        status: "scheduled",
        kind: "scheduled",
        channel: "web_reception",
        modality: "presential",
        duration_minutes: 30
      )
    end

    post "/api/v1/citizen/teleconsultation_sessions",
         params: { scheduled_at: 1.day.from_now.iso8601, appointment_id: appointment.id },
         headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

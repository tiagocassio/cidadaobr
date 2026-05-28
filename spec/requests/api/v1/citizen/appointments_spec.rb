# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Citizen appointments API", type: :request do
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

  let!(:service_type) do
    with_tenant(tenant_scope) do
      AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
    end
  end
  let!(:room) do
    with_tenant(tenant_scope) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
    end
  end
  let!(:capacity_slot) do
    with_tenant(tenant_scope) do
      RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        slot_date: Date.current,
        starts_at: "10:00",
        ends_at: "10:20",
        capacity: 1,
        booked_count: 0
      )
    end
  end

  it "lists available slots" do
    get "/api/v1/citizen/appointments/slots",
        params: { health_facility_id: facility.id, date: Date.current },
        headers: auth_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).not_to be_empty
    expect(body.first).to include("id", "starts_at", "remaining_capacity")
  end

  it "books and cancels an appointment" do
    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: auth_headers

    expect(response).to have_http_status(:created)
    appointment_id = JSON.parse(response.body).fetch("id")

    post "/api/v1/citizen/appointments/#{appointment_id}/cancel", headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("status")).to eq("cancelled")
  end

  it "rejects cancel for completed appointments" do
    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: auth_headers

    appointment_id = JSON.parse(response.body).fetch("id")

    with_tenant(Cidadaobr::TenantScope.new(municipality_id: municipality.id, scope: "municipality", health_facility_id: nil, team_ids: [], citizen_id: nil)) do
      Appointment.find(appointment_id).update!(status: "completed")
    end

    post "/api/v1/citizen/appointments/#{appointment_id}/cancel", headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Appointment cannot be cancelled")
  end

  it "rejects slots for another facility" do
    other_facility = with_tenant(tenant_scope) { create(:health_facility, municipality: municipality) }

    get "/api/v1/citizen/appointments/slots",
        params: { health_facility_id: other_facility.id, date: Date.current },
        headers: auth_headers

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)).to eq("error" => "Citizen is not linked to the selected facility")
  end

  it "rejects booking when citizen is not linked to a health facility" do
    unlinked_citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: nil, care_team: nil)
    end
    unlinked_account = with_tenant(tenant_scope) do
      CitizenAccount.create!(municipality: municipality, citizen: unlinked_citizen, cpf: unlinked_citizen.cpf, password: "password123")
    end
    unlinked_headers = { "Authorization" => "Bearer #{JwtTokenService.encode_citizen(account: unlinked_account)}" }

    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: unlinked_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Citizen must be linked to a health facility before booking")
  end

  it "rejects booking when room and slot do not match the citizen facility" do
    other_room = with_tenant(tenant_scope) do
      other_facility = create(:health_facility, municipality: municipality)
      ConsultationRoom.create!(municipality: municipality, health_facility: other_facility, name: "Sala 2", room_kind: "general")
    end

    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: other_room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Invalid room or slot for citizen facility")
  end

  it "returns conflict when slot capacity cannot be released" do
    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: auth_headers

    appointment_id = JSON.parse(response.body).fetch("id")

    allow(Scheduling::SlotCapacity).to receive(:release!)
      .and_raise(Scheduling::Errors::SlotUnavailableError, "Could not release slot capacity")

    post "/api/v1/citizen/appointments/#{appointment_id}/cancel", headers: auth_headers

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body).fetch("error")).to include("Could not release slot capacity")

    with_tenant(Cidadaobr::TenantScope.new(municipality_id: municipality.id, scope: "municipality", health_facility_id: nil, team_ids: [], citizen_id: nil)) do
      expect(Appointment.find(appointment_id).status).to eq("scheduled")
    end
  end

  it "returns unprocessable entity for invalid slot date" do
    get "/api/v1/citizen/appointments/slots",
        params: { health_facility_id: facility.id, date: "not-a-date" },
        headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Invalid date")
  end

  it "reschedules an appointment to another slot in the same room" do
    later_slot = with_tenant(tenant_scope) do
      RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        slot_date: Date.current,
        starts_at: "11:00",
        ends_at: "11:20",
        capacity: 1,
        booked_count: 0
      )
    end

    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: auth_headers

    appointment_id = JSON.parse(response.body).fetch("id")

    post "/api/v1/citizen/appointments/#{appointment_id}/reschedule",
         params: {
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 11:00").iso8601,
           room_capacity_slot_id: later_slot.id
         },
         headers: auth_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.fetch("status")).to eq("scheduled")
    expect(Time.zone.parse(body.fetch("scheduled_at"))).to eq(Time.zone.parse("#{Date.current} 11:00"))
  end

  it "rejects reschedule to a different consultation room" do
    other_room = with_tenant(tenant_scope) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 2", room_kind: "general")
    end
    other_slot = with_tenant(tenant_scope) do
      RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: other_room,
        slot_date: Date.current,
        starts_at: "11:00",
        ends_at: "11:20",
        capacity: 1,
        booked_count: 0
      )
    end

    post "/api/v1/citizen/appointments",
         params: {
           appointment_service_type_id: service_type.id,
           consultation_room_id: room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 10:00").iso8601,
           room_capacity_slot_id: capacity_slot.id
         },
         headers: auth_headers

    appointment_id = JSON.parse(response.body).fetch("id")

    post "/api/v1/citizen/appointments/#{appointment_id}/reschedule",
         params: {
           consultation_room_id: other_room.id,
           scheduled_at: Time.zone.parse("#{Date.current} 11:00").iso8601,
           room_capacity_slot_id: other_slot.id
         },
         headers: auth_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)).to eq("error" => "Invalid room for this appointment")
  end
end

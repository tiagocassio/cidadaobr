# frozen_string_literal: true

require "rails_helper"

RSpec.describe Indicators::RecalculateForAppointment do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  before { load Rails.root.join("db/seeds/indicator_catalog.rb") }

  it "recalculates appointment-dependent indicators by default" do
    service_type = with_tenant(membership) do
      AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta médica")
    end
    room = with_tenant(membership) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
    end
    slot = with_tenant(membership) do
      RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        slot_date: Date.current,
        starts_at: "09:00",
        ends_at: "09:20",
        capacity: 1,
        booked_count: 0
      )
    end
    citizen = with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
    appointment = with_tenant(membership) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        room_capacity_slot_id: slot.id,
        scheduled_at: slot.slot_date.in_time_zone.change(hour: 9)
      )
    end

    allow(Indicators::DetectCitizenGaps).to receive(:call).and_return({ gaps_opened: 0, gaps_resolved: 0, citizens_processed: 1 })
    allow(Indicators::RecalculateTeamScore).to receive(:call).and_return([])

    result = with_tenant(membership) do
      described_class.call(appointment_id: appointment.id)
    end

    expect(result[:skipped]).to be(false)
    expect(result[:indicator_codes]).to include("C1")
    expect(Indicators::DetectCitizenGaps).to have_received(:call).with(
      hash_including(citizen_id: citizen.id, indicator_codes: include("C1"))
    )
  end
end

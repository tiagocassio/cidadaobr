# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scheduling::FacilityDailySchedule do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "returns appointments and capacity slots for the day" do
    with_tenant(membership) do
      service_type = AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
      room = ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      slot = RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        slot_date: Date.current,
        starts_at: "08:00",
        ends_at: "08:20",
        capacity: 1,
        booked_count: 0
      )
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 08:00"),
        room_capacity_slot_id: slot.id
      )

      data = described_class.new(health_facility_id: facility.id, date: Date.current).call

      expect(data[:capacity_slots].size).to eq(1)
      expect(data[:appointments].size).to eq(1)
    end
  end
end

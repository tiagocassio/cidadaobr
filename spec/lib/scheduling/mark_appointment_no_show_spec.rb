# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scheduling::MarkAppointmentNoShow do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "facility", health_facility: facility)
  end

  let!(:service_type) do
    with_tenant(membership) do
      AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
    end
  end

  let!(:room) do
    with_tenant(membership) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
    end
  end

  let!(:capacity_slot) do
    with_tenant(membership) do
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
  end

  let!(:citizen) do
    with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end

  def book_appointment!
    with_tenant(membership) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: capacity_slot.id,
        care_team_id: team.id
      )
    end
  end

  it "marks scheduled appointments as no_show and releases the slot" do
    appointment = book_appointment!
    with_tenant(membership) do
      expect(capacity_slot.reload.booked_count).to eq(1)
      expect(appointment.appointment_room_slot).to be_present

      result = described_class.call(appointment: appointment.reload)

      expect(result.status).to eq("no_show")
      expect(capacity_slot.reload.booked_count).to eq(0)
      expect(appointment.reload.appointment_room_slot).to be_nil
    end
  end

  it "allows no_show from checked_in" do
    appointment = book_appointment!
    with_tenant(membership) do
      Scheduling::CheckInAppointment.call(appointment: appointment.reload)
      result = described_class.call(appointment: appointment.reload)
      expect(result.status).to eq("no_show")
    end
  end

  it "rejects completed appointments" do
    appointment = book_appointment!
    with_tenant(membership) do
      Scheduling::CheckInAppointment.call(appointment: appointment.reload)
      Scheduling::CompleteAppointment.call(appointment: appointment.reload)
      expect { described_class.call(appointment: appointment.reload) }.to raise_error(Scheduling::Errors::InvalidTransitionError)
    end
  end
end

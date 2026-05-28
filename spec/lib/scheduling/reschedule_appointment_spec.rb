# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scheduling::RescheduleAppointment do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "facility", health_facility: facility)
  end

  let!(:service_type) do
    with_tenant(membership) do
      AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta médica")
    end
  end

  let!(:room) do
    with_tenant(membership) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
    end
  end

  let!(:old_slot) do
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

  let!(:new_slot) do
    with_tenant(membership) do
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

  let!(:citizen) do
    with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end

  it "moves the appointment without leaving the old slot reserved when the new slot is unavailable" do
    appointment = with_tenant(membership) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: old_slot.id
      )
    end

    allow(Scheduling::SlotCapacity).to receive(:reserve!).and_call_original
    allow(Scheduling::SlotCapacity).to receive(:reserve!).with(new_slot.id).and_raise(Scheduling::Errors::SlotUnavailableError, "full")

    expect do
      with_tenant(membership) do
        described_class.call(
          appointment: appointment,
          scheduled_at: Time.zone.parse("#{Date.current} 10:00"),
          room_capacity_slot_id: new_slot.id
        )
      end
    end.to raise_error(Scheduling::Errors::SlotUnavailableError)

    with_tenant(membership) do
      expect(appointment.reload.appointment_room_slot.room_capacity_slot_id).to eq(old_slot.id)
      expect(old_slot.reload.booked_count).to eq(1)
      expect(new_slot.reload.booked_count).to eq(0)
    end
  end

  it "keeps the same slot reserved when rescheduling to the same capacity slot" do
    appointment = with_tenant(membership) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: old_slot.id
      )
    end

    new_time = Time.zone.parse("#{Date.current} 09:00")

    with_tenant(membership) do
      described_class.call(
        appointment: appointment,
        scheduled_at: new_time,
        room_capacity_slot_id: old_slot.id
      )

      expect(appointment.reload.scheduled_at).to eq(new_time)
      expect(appointment.appointment_room_slot.room_capacity_slot_id).to eq(old_slot.id)
      expect(old_slot.reload.booked_count).to eq(1)
    end
  end
end

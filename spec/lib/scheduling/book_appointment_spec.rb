# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scheduling commands", type: :model do
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

  it "books an appointment and prevents double booking" do
    appointment = with_tenant(membership) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: capacity_slot.id
      )
    end

    expect(appointment).to be_persisted

    expect {
      with_tenant(membership) do
        Scheduling::BookAppointment.call(
          citizen_id: citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
          room_capacity_slot_id: capacity_slot.id
        )
      end
    }.to raise_error(Scheduling::Errors::SlotUnavailableError)
  end

  it "rejects booking when scheduled_at does not match the selected slot" do
    expect {
      with_tenant(membership) do
        Scheduling::BookAppointment.call(
          citizen_id: citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          scheduled_at: Time.zone.parse("#{Date.current} 11:00"),
          room_capacity_slot_id: capacity_slot.id
        )
      end
    }.to raise_error(Scheduling::Errors::SlotUnavailableError, /does not match/)
  end

  it "allows multiple bookings while capacity remains" do
    with_tenant(membership) do
      capacity_slot.update!(capacity: 2)

      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: capacity_slot.id
      )

      other_citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      appointment = Scheduling::BookAppointment.call(
        citizen_id: other_citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: capacity_slot.id
      )

      expect(appointment).to be_persisted
      expect(capacity_slot.reload.booked_count).to eq(2)
    end
  end

  it "raises when releasing capacity twice" do
    appointment = with_tenant(membership) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: capacity_slot.id
      )
    end

    with_tenant(membership) do
      Scheduling::CancelAppointment.call(appointment: appointment)
      expect {
        Scheduling::SlotCapacity.release!(capacity_slot.id)
      }.to raise_error(Scheduling::Errors::SlotUnavailableError, /Could not release/)
    end
  end
end

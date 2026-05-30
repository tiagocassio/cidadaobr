# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scheduling::BookWalkInAppointment do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:citizen) { create(:citizen, municipality: municipality, health_facility: facility) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }
  let(:service_type) do
    AppointmentServiceType.create!(
      municipality: municipality,
      name: "Acolhimento",
      code: "ACOL",
      default_duration_minutes: 20,
      active: true
    )
  end
  let(:room) do
    ConsultationRoom.create!(
      municipality: municipality,
      health_facility: facility,
      name: "Sala 1",
      active: true
    )
  end

  it "creates a checked-in walk-in appointment" do
    with_tenant(membership) do
      appointment = described_class.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id
      )

      expect(appointment.kind).to eq("walk_in")
      expect(appointment.channel).to eq("walk_in")
      expect(appointment.status).to eq("checked_in")
    end
  end
end

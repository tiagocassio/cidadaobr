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

  it "rejects an invalid reference code for the active release" do
    ReferenceDataRelease.create!(
      release_key: "walk-in-release",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      sigtap_competence: "202602",
      checksum: "walkin123",
      manifest_json: { "domains" => [ { "key" => "ciap2" } ] },
      published_at: Time.current
    )

    with_tenant(membership) do
      expect do
        described_class.call(
          citizen_id: citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          ciap2_code: "INVALID"
        )
      end.to raise_error(ArgumentError, /invalid reference code for ciap2/)
    end
  end

  it "rejects SIGTAP codes from a stale competence" do
    ReferenceDataRelease.create!(
      release_key: "walk-in-sigtap",
      ledi_version: Rails.application.config.ledi.fetch(:version),
      sigtap_competence: "202602",
      checksum: "walkinsigtap",
      manifest_json: { "domains" => [ { "key" => "sigtap_procedure" } ] },
      published_at: Time.current
    )
    ReferenceDomainEntry.create!(
      domain_key: "sigtap_procedure",
      code: "0301010070",
      label: "Legacy procedure",
      active: true,
      payload_json: { "competence" => "202601" }
    )

    with_tenant(membership) do
      expect do
        described_class.call(
          citizen_id: citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          sigtap_procedure_code: "0301010070"
        )
      end.to raise_error(ArgumentError, /invalid reference code for sigtap_procedure/)
    end
  end
end

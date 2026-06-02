# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndicatorRecalculationConsumer, type: :consumer do
  let(:municipality_a) { create(:municipality) }
  let(:municipality_b) { create(:municipality) }
  let(:facility_a) { create(:health_facility, municipality: municipality_a) }
  let(:facility_b) { create(:health_facility, municipality: municipality_b) }
  let(:team_a) { create(:care_team, municipality: municipality_a, health_facility: facility_a) }
  let(:membership_a) do
    create(:user_municipality_membership, municipality: municipality_a, health_facility: facility_a, scope: "facility")
  end

  let!(:service_type) do
    with_tenant(membership_a) do
      AppointmentServiceType.create!(municipality: municipality_a, code: "medical_consultation", name: "Consulta")
    end
  end

  let!(:room) do
    with_tenant(membership_a) do
      ConsultationRoom.create!(municipality: municipality_a, health_facility: facility_a, name: "Sala", room_kind: "general")
    end
  end

  let!(:slot) do
    with_tenant(membership_a) do
      RoomCapacitySlot.create!(
        municipality: municipality_a,
        health_facility: facility_a,
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
    with_tenant(membership_a) do
      create(:citizen, municipality: municipality_a, health_facility: facility_a, care_team: team_a)
    end
  end

  let!(:appointment) do
    with_tenant(membership_a) do
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: slot.id,
        care_team_id: team_a.id
      )
    end
  end

  it "recalculates only under the envelope municipality tenant" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality_a.id,
      "health_facility_id" => facility_a.id,
      "payload" => { "appointment_id" => appointment.id }
    }

    consumer = described_class.new
    message = instance_double("Karafka message", payload: envelope.to_json)
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(
      instance_double("Karafka topic", name: Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED)
    )

    expect(Indicators::RecalculateForAppointment).to receive(:call).with(appointment_id: appointment.id).once

    with_tenant(membership_a) { consumer.consume }
  end

  it "does not load appointments from another municipality" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality_b.id,
      "health_facility_id" => facility_b.id,
      "payload" => { "appointment_id" => appointment.id }
    }

    consumer = described_class.new
    message = instance_double("Karafka message", payload: envelope.to_json)
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(
      instance_double("Karafka topic", name: Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED)
    )

    membership_b = create(
      :user_municipality_membership,
      municipality: municipality_b,
      health_facility: facility_b,
      scope: "facility"
    )

    marked_messages = []
    consumer.define_singleton_method(:mark_as_consumed) { |msg| marked_messages << msg }
    allow(Rails.logger).to receive(:error)

    with_tenant(membership_b) { consumer.consume }

    expect(marked_messages).to eq([ message ])
    expect(KafkaProcessedEvent.count).to eq(0)
  end
end

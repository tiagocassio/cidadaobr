# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndicatorRecalculationConsumer do
  let(:municipality) { create(:municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }

  def consume_envelope(envelope, topic_name:)
    message = instance_double("Karafka message", payload: envelope.to_json)
    consumer = described_class.new
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: topic_name))
    consumer.consume
  end

  it "recalculates indicators for appointment.noshow" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "event_type" => Cidadaobr::KafkaTopics::APPOINTMENT_NOSHOW,
      "payload" => { "appointment_id" => SecureRandom.uuid }
    }

    allow(Indicators::RecalculateForAppointment).to receive(:call)

    consume_envelope(envelope, topic_name: Cidadaobr::KafkaTopics::APPOINTMENT_NOSHOW)

    expect(Indicators::RecalculateForAppointment).to have_received(:call).with(
      appointment_id: envelope.dig("payload", "appointment_id")
    )
  end

  it "recalculates indicators for appointment.cancelled" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "event_type" => Cidadaobr::KafkaTopics::APPOINTMENT_CANCELLED,
      "payload" => { "appointment_id" => SecureRandom.uuid }
    }

    allow(Indicators::RecalculateForAppointment).to receive(:call)

    consume_envelope(envelope, topic_name: Cidadaobr::KafkaTopics::APPOINTMENT_CANCELLED)

    expect(Indicators::RecalculateForAppointment).to have_received(:call).with(
      appointment_id: envelope.dig("payload", "appointment_id")
    )
  end

  it "runs recalculation end-to-end for appointment.booked without stubbing the command" do
    facility = create(:health_facility, municipality: municipality)
    team = create(:care_team, municipality: municipality, health_facility: facility)
    facility_membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility"
    )

    appointment = with_tenant(facility_membership) do
      service_type = AppointmentServiceType.create!(
        municipality: municipality,
        code: "medical_consultation",
        name: "Consulta"
      )
      room = ConsultationRoom.create!(
        municipality: municipality,
        health_facility: facility,
        name: "Sala",
        room_kind: "general"
      )
      slot = RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        slot_date: Date.current,
        starts_at: "09:00",
        ends_at: "09:20",
        capacity: 1,
        booked_count: 0
      )
      citizen = create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      Scheduling::BookAppointment.call(
        citizen_id: citizen.id,
        appointment_service_type_id: service_type.id,
        consultation_room_id: room.id,
        scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
        room_capacity_slot_id: slot.id,
        care_team_id: team.id
      )
    end

    load Rails.root.join("db/seeds/indicator_catalog.rb")

    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "health_facility_id" => facility.id,
      "payload" => { "appointment_id" => appointment.id }
    }

    expect do
      with_tenant(facility_membership) { consume_envelope(envelope, topic_name: Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED) }
    end.not_to raise_error

    expect(KafkaProcessedEvent.find_by(event_id: envelope["event_id"])).to be_present
  end
end

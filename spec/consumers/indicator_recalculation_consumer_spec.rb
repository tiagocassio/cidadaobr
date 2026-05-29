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

  it "recalculates indicators for appointment.cancelled" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "event_type" => "appointment.cancelled",
      "payload" => { "appointment_id" => SecureRandom.uuid }
    }

    allow(Indicators::RecalculateForAppointment).to receive(:call)

    consume_envelope(envelope, topic_name: "appointment.cancelled")

    expect(Indicators::RecalculateForAppointment).to have_received(:call).with(
      appointment_id: envelope.dig("payload", "appointment_id")
    )
  end
end

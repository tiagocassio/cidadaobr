# frozen_string_literal: true

require "rails_helper"

RSpec.describe OutboxPublisher, type: :service do
  let(:message) do
    OutboxMessage.new(
      id: SecureRandom.uuid,
      domain_event_id: SecureRandom.uuid,
      municipality_id: SecureRandom.uuid,
      topic: "domain.outbox",
      event_type: "platform.bootstrapped",
      payload: { event_id: SecureRandom.uuid },
      status: "pending"
    )
  end

  it "marks message as published when producer succeeds" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    allow(message).to receive(:update!)

    described_class.publish!(message)

    expect(message).to have_received(:update!).with(hash_including(status: "published"))
    expect(producer).to have_received(:produce_sync)
  end
end

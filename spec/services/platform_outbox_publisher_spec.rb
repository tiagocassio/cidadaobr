# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlatformOutboxPublisher, type: :service do
  let(:platform_event_id) { SecureRandom.uuid }
  let(:message) do
    PlatformOutboxMessage.new(
      id: SecureRandom.uuid,
      platform_event_id: platform_event_id,
      topic: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED,
      event_type: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED,
      payload: { "event_id" => platform_event_id },
      status: "pending"
    )
  end

  it "marks message as published when producer succeeds" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    allow(message).to receive(:reload).and_return(message)
    allow(message).to receive(:update!)

    described_class.publish!(message)

    expect(producer).to have_received(:produce_sync).with(
      hash_including(topic: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED, key: platform_event_id)
    )
  end
end

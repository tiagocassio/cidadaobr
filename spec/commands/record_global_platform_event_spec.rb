# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecordGlobalPlatformEvent do
  let(:aggregate_id) { SecureRandom.uuid }

  it "appends platform event and outbox message" do
    event = described_class.call(
      event_type: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED,
      aggregate_type: "ReferenceDataRelease",
      aggregate_id: aggregate_id,
      payload: { release_key: "test:abc" }
    )

    expect(event).to be_persisted
    expect(PlatformOutboxMessage.find_by(platform_event_id: event.id)).to have_attributes(
      status: "pending",
      topic: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED,
      event_type: Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED
    )
    expect(PlatformOutboxMessage.last.payload["municipality_id"]).to be_nil
  end
end

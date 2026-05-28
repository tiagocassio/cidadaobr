# frozen_string_literal: true

require "rails_helper"

RSpec.describe KafkaProcessedEvent, type: :model do
  it "enforces idempotency keys" do
    attrs = {
      event_id: SecureRandom.uuid,
      topic: "domain.outbox",
      consumer_group: "cidadaobr_saude",
      processed_at: Time.current
    }

    described_class.create!(attrs)
    duplicate = described_class.new(attrs)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:event_id]).to be_present
  end
end

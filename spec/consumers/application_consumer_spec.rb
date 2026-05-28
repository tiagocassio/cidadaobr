# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationConsumer do
  let(:test_consumer_class) do
    Class.new(described_class) do
      attr_reader :processed_payload

      def consume
        messages.each do |message|
          process_with_idempotency(message) do |payload|
            @processed_payload = payload
          end
        end
      end
    end
  end

  it "skips envelopes without municipality_id" do
    consumer = test_consumer_class.new
    message = instance_double("Karafka message", payload: { event_id: SecureRandom.uuid }.to_json)
    marked_messages = []
    consumer.define_singleton_method(:mark_as_consumed) { |msg| marked_messages << msg }
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "test.topic"))

    consumer.consume

    expect(marked_messages).to eq([ message ])
    expect(KafkaProcessedEvent.count).to eq(0)
  end

  it "marks poison envelopes as consumed without idempotency side effects" do
    consumer = test_consumer_class.new
    message = instance_double("Karafka message", payload: "not-json")
    marked_messages = []
    consumer.define_singleton_method(:mark_as_consumed) { |msg| marked_messages << msg }
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "test.topic"))

    consumer.consume

    expect(marked_messages).to eq([ message ])
    expect(KafkaProcessedEvent.count).to eq(0)
  end

  it "skips duplicate event_id without re-running side effects" do
    municipality = create(:municipality)
    facility = create(:health_facility, municipality: municipality)
    membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility"
    )
    event_id = SecureRandom.uuid
    envelope = {
      "event_id" => event_id,
      "municipality_id" => municipality.id,
      "health_facility_id" => facility.id,
      "payload" => { "ok" => true }
    }

    consumer = test_consumer_class.new
    message = instance_double("Karafka message", payload: envelope.to_json)
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "test.topic"))

    with_tenant(membership) do
      consumer.consume
      expect(consumer.processed_payload).to eq(envelope.stringify_keys)
      expect(KafkaProcessedEvent.where(event_id: event_id).count).to eq(1)

      consumer.consume
      expect(KafkaProcessedEvent.where(event_id: event_id).count).to eq(1)
    end
  end

  it "raises on non-duplicate KafkaProcessedEvent validation failures" do
    municipality = create(:municipality)
    facility = create(:health_facility, municipality: municipality)
    membership = create(
      :user_municipality_membership,
      municipality: municipality,
      health_facility: facility,
      scope: "facility"
    )
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "health_facility_id" => facility.id,
      "payload" => { "ok" => true }
    }

    consumer = test_consumer_class.new
    message = instance_double("Karafka message", payload: envelope.to_json)
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "test.topic"))

    broken_event = KafkaProcessedEvent.new(
      event_id: envelope["event_id"],
      topic: "test.topic",
      consumer_group: KarafkaApp.config.client_id,
      processed_at: Time.current
    )
    allow(broken_event).to receive(:save!).and_raise(
      ActiveRecord::RecordInvalid.new(broken_event.tap { |record| record.errors.add(:topic, :blank) })
    )
    allow(KafkaProcessedEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(broken_event))

    expect do
      with_tenant(membership) { consumer.consume }
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(KafkaProcessedEvent.find_by(event_id: envelope["event_id"])).to be_nil
  end
end

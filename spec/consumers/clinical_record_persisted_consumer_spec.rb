# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClinicalRecordPersistedConsumer do
  let(:municipality) { create(:municipality, ibge_code: "3550308") }
  let(:facility) { create(:health_facility, municipality: municipality, cnes: "2000001") }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility")
  end

  before do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
  end

  def import_fci!
    with_tenant(membership) do
      Ledi::ImportTransportRecord.call(
        payload_binary: LediFixtures.fci_binary(cnes: facility.cnes, ibge: municipality.ibge_code)
      )[:clinical_record]
    end
  end

  def consume_envelope(envelope)
    message = instance_double("Karafka message", payload: envelope.to_json)
    consumer = described_class.new
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "clinical.record.persisted"))
    consumer.consume
  end

  it "projects clinical records under tenant context from the event envelope" do
    clinical_record = import_fci!

    with_tenant(membership) do
      Ledi::ValidateClinicalRecord.call(clinical_record_id: clinical_record.id)
    end

    event = with_tenant(membership) do
      DomainEvent.find_by!(event_type: "clinical.record.persisted", aggregate_id: clinical_record.id)
    end

    envelope = Cidadaobr::EventEnvelope.from_domain_event(event).to_h

    expect do
      consume_envelope(envelope)
    end.to change { with_tenant(membership) { Citizen.count } }.by(1)
  end

  it "does not mark missing clinical records as processed" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "health_facility_id" => facility.id,
      "event_type" => "clinical.record.persisted",
      "payload" => { "clinical_record_id" => SecureRandom.uuid },
      "occurred_at" => Time.current.iso8601
    }

    expect do
      consume_envelope(envelope)
    end.to raise_error(Ledi::Errors::MissingClinicalRecordError)

    expect(KafkaProcessedEvent.find_by(event_id: envelope["event_id"])).to be_nil
  end

  it "drops stale missing clinical records instead of retrying forever" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "health_facility_id" => facility.id,
      "event_type" => "clinical.record.persisted",
      "payload" => { "clinical_record_id" => SecureRandom.uuid },
      "occurred_at" => 5.minutes.ago.iso8601
    }
    message = instance_double("Karafka message", payload: envelope.to_json)
    consumer = described_class.new
    marked_messages = []
    consumer.define_singleton_method(:mark_as_consumed) { |msg| marked_messages << msg }
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "clinical.record.persisted"))

    expect { consumer.consume }.not_to raise_error

    expect(marked_messages).to eq([ message ])
    expect(KafkaProcessedEvent.find_by(event_id: envelope["event_id"])).to be_nil
  end

  it "drops stale missing clinical records using the kafka message timestamp when occurred_at is absent" do
    envelope = {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "health_facility_id" => facility.id,
      "event_type" => "clinical.record.persisted",
      "payload" => { "clinical_record_id" => SecureRandom.uuid }
    }
    message = instance_double(
      "Karafka message",
      payload: envelope.to_json,
      metadata: instance_double("metadata", timestamp: 5.minutes.ago)
    )
    consumer = described_class.new
    marked_messages = []
    consumer.define_singleton_method(:mark_as_consumed) { |msg| marked_messages << msg }
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "clinical.record.persisted"))

    expect { consumer.consume }.not_to raise_error

    expect(marked_messages).to eq([ message ])
    expect(KafkaProcessedEvent.find_by(event_id: envelope["event_id"])).to be_nil
  end
end

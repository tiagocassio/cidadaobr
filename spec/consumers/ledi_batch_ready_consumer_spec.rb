# frozen_string_literal: true

require "rails_helper"

RSpec.describe LediBatchReadyConsumer do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:batch) do
    with_tenant(membership) { create(:ledi_batch, municipality: municipality, status: "ready") }
  end

  def consume_envelope(envelope)
    message = instance_double("Karafka message", payload: envelope.to_json)
    consumer = described_class.new
    allow(consumer).to receive(:messages).and_return([ message ])
    allow(consumer).to receive(:topic).and_return(instance_double("Karafka topic", name: "ledi.batch.ready"))
    consumer.consume
  end

  def envelope_for(batch)
    {
      "event_id" => SecureRandom.uuid,
      "municipality_id" => municipality.id,
      "payload" => { "ledi_batch_id" => batch.id }
    }
  end

  it "marks ready batch as submitted and emits status_changed" do
    with_tenant(membership) do
      consume_envelope(envelope_for(batch))

      batch.reload
      expect(batch.status).to eq("submitted")
      expect(DomainEvent.where(event_type: "ledi.batch.status_changed", aggregate_id: batch.id).count).to eq(1)
    end
  end

  it "does not resubmit an already submitted batch on replay" do
    submitted_batch = with_tenant(membership) do
      create(:ledi_batch, municipality: municipality, status: "submitted")
    end

    with_tenant(membership) do
      consume_envelope(envelope_for(submitted_batch))

      expect(DomainEvent.where(event_type: "ledi.batch.status_changed", aggregate_id: submitted_batch.id).count).to eq(0)
    end
  end

  it "rejects batch when PEC stub is enabled and batch has no validated records" do
    original = ENV["LEDI_PEC_STUB_REJECT"]
    ENV["LEDI_PEC_STUB_REJECT"] = "true"

    with_tenant(membership) do
      consume_envelope(envelope_for(batch))

      batch.reload
      expect(batch.status).to eq("rejected")
      expect(batch.rejection_reason).to include("PEC rejeitou lote")
      expect(DomainEvent.where(event_type: "ledi.batch.status_changed", aggregate_id: batch.id).count).to eq(1)
    end
  ensure
    ENV["LEDI_PEC_STUB_REJECT"] = original
  end

  it "does not reject an already submitted batch when PEC stub is enabled" do
    original = ENV["LEDI_PEC_STUB_REJECT"]
    ENV["LEDI_PEC_STUB_REJECT"] = "true"
    submitted_batch = with_tenant(membership) do
      create(:ledi_batch, municipality: municipality, status: "submitted")
    end

    with_tenant(membership) do
      consume_envelope(envelope_for(submitted_batch))

      submitted_batch.reload
      expect(submitted_batch.status).to eq("submitted")
      expect(DomainEvent.where(event_type: "ledi.batch.status_changed", aggregate_id: submitted_batch.id).count).to eq(0)
    end
  ensure
    ENV["LEDI_PEC_STUB_REJECT"] = original
  end
end

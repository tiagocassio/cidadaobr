# frozen_string_literal: true

require "rails_helper"

RSpec.describe OutboxPublisher, type: :service do
  let(:domain_event_id) { SecureRandom.uuid }
  let(:message) do
    OutboxMessage.new(
      id: SecureRandom.uuid,
      domain_event_id: domain_event_id,
      municipality_id: SecureRandom.uuid,
      topic: "domain.outbox",
      event_type: "platform.bootstrapped",
      payload: { "event_id" => domain_event_id },
      status: "pending"
    )
  end

  it "marks message as published when producer succeeds" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    allow(message).to receive(:reload).and_return(message)
    allow(message).to receive(:update!)

    described_class.publish!(message)

    expect(message).to have_received(:update!).with(
      hash_including(kafka_sent_at: kind_of(Time), status: "published", published_at: kind_of(Time))
    )
    expect(producer).to have_received(:produce_sync).with(
      hash_including(topic: "domain.outbox", key: domain_event_id)
    )
  end

  it "marks failed when payload is missing event_id" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    message.payload = {}
    allow(message).to receive(:reload).and_return(message)
    allow(message).to receive(:update!)

    described_class.publish!(message)

    expect(message).to have_received(:update!).with(
      hash_including(status: "failed", last_error: "Outbox payload missing event_id", permanent_failure: true)
    )
    expect(producer).not_to have_received(:produce_sync)
  end

  it "reads event_id from symbol keys in payload" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    message.payload = { event_id: domain_event_id }
    allow(message).to receive(:reload).and_return(message)
    allow(message).to receive(:update!)

    described_class.publish!(message)

    expect(producer).to have_received(:produce_sync).with(
      hash_including(key: domain_event_id)
    )
  end

  it "skips produce when kafka was already sent and only marks published" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    sent_at = 1.minute.ago
    allow(message).to receive(:reload).and_return(message)
    allow(message).to receive(:status).and_return("publishing")
    allow(message).to receive(:kafka_sent_at).and_return(sent_at)
    allow(message).to receive(:update!)

    described_class.publish!(message)

    expect(producer).not_to have_received(:produce_sync)
    expect(message).to have_received(:update!).with(hash_including(status: "published"))
  end

  it "records kafka_sent_at before marking published so retry avoids duplicate produce" do
    producer = instance_double("producer", produce_sync: true)
    allow(Karafka).to receive(:producer).and_return(producer)
    allow(message).to receive(:reload).and_return(message)
    allow(message).to receive(:status).and_return("publishing")
    allow(message).to receive(:kafka_sent_at).and_return(nil)
    call_count = 0
    allow(message).to receive(:update!) do |attrs|
      call_count += 1
      raise ActiveRecord::StatementInvalid, "db unavailable" if call_count == 1

      expect(attrs).to include(:kafka_sent_at)
      expect(attrs).not_to include(:status)
      true
    end

    expect { described_class.publish!(message) }.to raise_error(ActiveRecord::StatementInvalid)

    expect(call_count).to eq(2)
    expect(producer).to have_received(:produce_sync).once
  end

  describe ".publish_pending!" do
    let(:municipality) { create(:municipality) }
    let(:membership) do
      create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
    end

    it "publishes pending messages under municipal tenant scope" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        expect(OutboxMessage.pending.count).to eq(1)
      end

      described_class.publish_pending!

      with_tenant(membership) do
        expect(OutboxMessage.where(status: "published").count).to eq(1)
      end
      expect(producer).to have_received(:produce_sync).once
    end

    it "continues publishing other messages when one publish fails" do
      producer = instance_double("producer")
      allow(Karafka).to receive(:producer).and_return(producer)
      attempts = 0
      allow(producer).to receive(:produce_sync) do
        attempts += 1
        raise StandardError, "broker down" if attempts == 1

        true
      end

      with_tenant(membership) do
        2.times do |index|
          CommandBus.dispatch(
            RecordPlatformEvent,
            event_type: "platform.bootstrapped",
            aggregate_type: "Platform",
            aggregate_id: SecureRandom.uuid,
            payload: { index: index },
            topic: "domain.outbox",
            metadata: {}
          )
        end

        expect(OutboxMessage.pending.count).to eq(2)
      end

      expect { described_class.publish_pending! }.not_to raise_error

      with_tenant(membership) do
        expect(OutboxMessage.where(status: "failed").count).to eq(1)
        expect(OutboxMessage.where(status: "published").count).to eq(1)
      end
      expect(producer).to have_received(:produce_sync).twice
    end

    it "reclaims stale publishing messages and publishes them" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "publishing",
          publishing_claimed_at: 16.minutes.ago,
          updated_at: Time.current
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        message = OutboxMessage.sole
        expect(message.status).to eq("published")
        expect(message.last_error).to be_nil
      end
      expect(producer).to have_received(:produce_sync).once
    end

    it "does not reclaim publishing messages still within the stale window" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "publishing",
          publishing_claimed_at: 1.minute.ago,
          updated_at: 16.minutes.ago
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        expect(OutboxMessage.where(status: "publishing").count).to eq(1)
      end
      expect(producer).not_to have_received(:produce_sync)
    end

    it "retries marking published without producing again when kafka_sent_at is set" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "publishing",
          kafka_sent_at: 1.minute.ago,
          publishing_claimed_at: 1.minute.ago
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        message = OutboxMessage.sole
        expect(message.status).to eq("published")
        expect(message.kafka_sent_at).to be_present
      end
      expect(producer).not_to have_received(:produce_sync)
    end

    it "interleaves publishing across municipalities instead of starving later ones" do
      other_municipality = create(:municipality)
      other_membership = create(
        :user_municipality_membership,
        municipality: other_municipality,
        scope: "municipality",
        role_code: "municipal_admin"
      )
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)
      published_municipalities = []

      allow(producer).to receive(:produce_sync) do
        published_municipalities << Cidadaobr::TenantContext.current.municipality_id
        true
      end

      with_tenant(membership) do
        2.times do
          CommandBus.dispatch(
            RecordPlatformEvent,
            event_type: "platform.bootstrapped",
            aggregate_type: "Platform",
            aggregate_id: SecureRandom.uuid,
            payload: { from: "first" },
            topic: "domain.outbox",
            metadata: {}
          )
        end
      end

      with_tenant(other_membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { from: "second" },
          topic: "domain.outbox",
          metadata: {}
        )
      end

      described_class.publish_pending!(limit: 3)

      expect(published_municipalities).to eq([
        municipality.id,
        other_municipality.id,
        municipality.id
      ])
    end

    it "reclaims publishing rows missing publishing_claimed_at using updated_at" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "publishing",
          publishing_claimed_at: nil,
          updated_at: 16.minutes.ago
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        expect(OutboxMessage.sole.status).to eq("published")
      end
      expect(producer).to have_received(:produce_sync).once
    end

    it "does not automatically requeue permanently failed messages" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "failed",
          last_error: "Outbox payload missing event_id",
          permanent_failure: true,
          updated_at: 6.minutes.ago
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        expect(OutboxMessage.sole.status).to eq("failed")
      end
      expect(producer).not_to have_received(:produce_sync)
    end

    it "automatically requeues failed messages after the retry backoff" do
      producer = instance_double("producer", produce_sync: true)
      allow(Karafka).to receive(:producer).and_return(producer)

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "failed",
          last_error: "broker down",
          updated_at: 6.minutes.ago
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        expect(OutboxMessage.sole.status).to eq("published")
      end
      expect(producer).to have_received(:produce_sync).once
    end

    it "marks failed as permanent after max publish attempts" do
      producer = instance_double("producer")
      allow(Karafka).to receive(:producer).and_return(producer)
      allow(producer).to receive(:produce_sync).and_raise(StandardError, "broker down")
      max_attempts = OutboxMessage::MAX_PUBLISH_ATTEMPTS

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.sole.update_columns(
          status: "failed",
          last_error: "broker down",
          publish_attempts: max_attempts - 1,
          updated_at: 6.minutes.ago
        )
      end

      described_class.publish_pending!

      with_tenant(membership) do
        message = OutboxMessage.sole
        expect(message.status).to eq("failed")
        expect(message.publish_attempts).to eq(max_attempts)
        expect(message.permanent_failure).to be(true)
        expect(message.last_error).to include("max publish attempts exceeded")
      end
    end

    it "appends reclaim reason without dropping prior last_error" do
      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "publishing",
          last_error: "broker down",
          publishing_claimed_at: 16.minutes.ago
        )

        described_class.send(:reclaim_stale_publishing!)

        expect(OutboxMessage.sole.last_error).to eq(
          "broker down | #{OutboxPublisher::RECLAIMED_STALE_MESSAGE}"
        )
      end
    end
  end

  describe ".retry_failed!" do
    let(:municipality) { create(:municipality) }
    let(:membership) do
      create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
    end

    it "requeues failed messages to pending" do
      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(status: "failed", last_error: "broker down")
      end

      described_class.retry_failed!

      with_tenant(membership) do
        message = OutboxMessage.sole
        expect(message.status).to eq("pending")
        expect(message.last_error).to be_nil
        expect(message.kafka_sent_at).to be_nil
      end
    end

    it "preserves kafka_sent_at when manually requeueing failed messages" do
      sent_at = 2.minutes.ago

      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "failed",
          last_error: "db unavailable",
          kafka_sent_at: sent_at
        )
      end

      described_class.retry_failed!

      with_tenant(membership) do
        message = OutboxMessage.sole
        expect(message.status).to eq("pending")
        expect(message.kafka_sent_at).to be_within(1.second).of(sent_at)
      end
    end

    it "skips permanently failed messages unless force is set" do
      with_tenant(membership) do
        CommandBus.dispatch(
          RecordPlatformEvent,
          event_type: "platform.bootstrapped",
          aggregate_type: "Platform",
          aggregate_id: SecureRandom.uuid,
          payload: { ok: true },
          topic: "domain.outbox",
          metadata: {}
        )

        OutboxMessage.pending.sole.update_columns(
          status: "failed",
          last_error: "Outbox payload missing event_id",
          permanent_failure: true
        )
      end

      described_class.retry_failed!

      with_tenant(membership) do
        expect(OutboxMessage.sole.status).to eq("failed")
      end

      described_class.retry_failed!(force: true)

      with_tenant(membership) do
        message = OutboxMessage.sole
        expect(message.status).to eq("pending")
        expect(message.publish_attempts).to eq(0)
      end
    end
  end
end

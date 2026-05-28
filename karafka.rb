# frozen_string_literal: true

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    }
    config.client_id = "cidadaobr_saude"
    config.consumer_persistence = !Rails.env.development?
  end

  routes.draw do
    # Transient MissingClinicalRecordError retries until ClinicalRecordPersistedConsumer::PROJECTION_RETRY_GRACE elapses, then the message is dropped.
    topic "clinical.record.persisted" do
      consumer ClinicalRecordPersistedConsumer
    end

    topic "ledi.batch.ready" do
      consumer LediBatchReadyConsumer
    end

    topic "citizen.registered" do
      consumer CitizenRegisteredConsumer
    end

    topic "domain.outbox" do
      consumer DomainOutboxConsumer
    end
  end
end

if defined?(Karafka::Web) && Karafka::Web.respond_to?(:setup)
  Karafka::Web.setup do |config|
    config.ui.sessions.secret = Rails.application.secret_key_base
  end

  Karafka::Web.enable! if Rails.env.development?
end

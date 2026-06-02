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
    # Publish-only topics: see Cidadaobr::KafkaTopics::ALL vs ROUTED and docs/adr/0007-kafka-topic-consumer-policy.md

    topic Cidadaobr::KafkaTopics::CLINICAL_RECORD_PERSISTED do
      consumer ClinicalRecordPersistedConsumer
    end

    topic Cidadaobr::KafkaTopics::LEDI_BATCH_SUBMITTED do
      consumer LediBatchReadyConsumer
    end

    topic Cidadaobr::KafkaTopics::LEDI_BATCH_STATUSCHANGED do
      consumer PlatformEventConsumer
    end

    [
      Cidadaobr::KafkaTopics::APPOINTMENT_BOOKED,
      Cidadaobr::KafkaTopics::APPOINTMENT_WALK_IN_BOOKED,
      Cidadaobr::KafkaTopics::APPOINTMENT_CHECKEDIN,
      Cidadaobr::KafkaTopics::APPOINTMENT_RESCHEDULED,
      Cidadaobr::KafkaTopics::APPOINTMENT_COMPLETED,
      Cidadaobr::KafkaTopics::APPOINTMENT_CANCELLED,
      Cidadaobr::KafkaTopics::APPOINTMENT_NOSHOW
    ].each do |topic_name|
      topic topic_name do
        consumer IndicatorRecalculationConsumer
      end
    end

    topic Cidadaobr::KafkaTopics::INDICATOR_GAP_DETECTED do
      consumer PlatformEventConsumer
    end

    topic Cidadaobr::KafkaTopics::INDICATOR_TEAM_SCORE_UPDATED do
      consumer PlatformEventConsumer
    end

    topic Cidadaobr::KafkaTopics::CITIZEN_REGISTERED do
      consumer CitizenRegisteredConsumer
    end

    topic Cidadaobr::KafkaTopics::DOMAIN_OUTBOX do
      consumer DomainOutboxConsumer
    end

    topic Cidadaobr::KafkaTopics::REFERENCE_RELEASE_PUBLISHED do
      consumer ReferenceDataReleasePublishedConsumer
    end
  end
end

if defined?(Karafka::Web) && Karafka::Web.respond_to?(:setup)
  Karafka::Web.setup do |config|
    config.ui.sessions.secret = Rails.application.secret_key_base
  end

  Karafka::Web.enable! if Rails.env.development?
end

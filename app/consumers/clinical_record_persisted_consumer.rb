# frozen_string_literal: true

class ClinicalRecordPersistedConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      process_with_idempotency(message) do |_payload|
        Rails.logger.info("[Kafka] clinical.record.persisted processed")
      end
    end
  end
end

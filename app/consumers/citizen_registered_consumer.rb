# frozen_string_literal: true

class CitizenRegisteredConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      process_with_idempotency(message) do |_payload|
        Rails.logger.info("[Kafka] citizen.registered processed")
      end
    end
  end
end

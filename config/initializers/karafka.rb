# frozen_string_literal: true

if Rails.env.development? || Rails.env.test?
  Rails.application.config.after_initialize do
    Karafka.producer
  rescue StandardError => e
    Rails.logger.warn("Karafka producer unavailable: #{e.message}") unless Rails.env.test?
  end
end

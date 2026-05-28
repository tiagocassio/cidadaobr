# frozen_string_literal: true

# Subscribe to OutboxPublisher instrumentation for logs/metrics wiring.
# Hook Prometheus/Datadog/etc. here on "outbox.publish_failed".
ActiveSupport::Notifications.subscribe("outbox.publish_failed") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload

  Rails.logger.warn(
    "[OutboxPublisher] publish_failed " \
    "message_id=#{payload[:message_id]} " \
    "municipality_id=#{payload[:municipality_id]} " \
    "error_class=#{payload[:error_class]} " \
    "error_message=#{payload[:error_message]}"
  )
end

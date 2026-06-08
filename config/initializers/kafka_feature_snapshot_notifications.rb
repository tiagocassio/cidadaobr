# frozen_string_literal: true

# Subscribe to feature-snapshot skip instrumentation for logs/metrics wiring.
# Hook Prometheus/Datadog/etc. here on "kafka.feature_snapshot.rls_skipped".
ActiveSupport::Notifications.subscribe("kafka.feature_snapshot.rls_skipped") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload

  Rails.logger.error(
    "[Kafka] feature_snapshot.rls_skipped " \
    "clinical_record_id=#{payload[:clinical_record_id]} " \
    "error_class=#{payload[:error_class]} " \
    "error_message=#{payload[:error_message]}"
  )
end

ActiveSupport::Notifications.subscribe("kafka.feature_snapshot.validation_skipped") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload

  Rails.logger.warn(
    "[Kafka] feature_snapshot.validation_skipped " \
    "clinical_record_id=#{payload[:clinical_record_id]} " \
    "validation_status=#{payload[:validation_status]}"
  )
end

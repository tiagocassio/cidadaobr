# frozen_string_literal: true

# Recalculates indicators referenced by appointment_in_quadrimester (see RuleCatalog.appointment_dependent_codes).
class IndicatorRecalculationConsumer < ApplicationConsumer
  APPOINTMENT_TOPICS = %w[
    appointment.booked
    appointment.checkedin
    appointment.rescheduled
    appointment.completed
    appointment.cancelled
    appointment.noshow
  ].freeze

  def consume
    messages.each do |message|
      process_with_idempotency(message) do |payload|
        next unless APPOINTMENT_TOPICS.include?(topic.name)

        appointment_id = payload.dig("payload", "appointment_id") || payload["appointment_id"]
        next if appointment_id.blank?

        Indicators::RecalculateForAppointment.call(appointment_id: appointment_id)
      end
    end
  end
end

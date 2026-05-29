# frozen_string_literal: true

module Scheduling
  class FacilityUtilizationReport
    COUNTED_STATUSES = %w[scheduled confirmed checked_in in_progress completed no_show cancelled].freeze

    def initialize(health_facility_id:, from_date:, to_date:)
      @health_facility_id = health_facility_id
      @from_date = from_date.to_date
      @to_date = to_date.to_date
      raise ArgumentError, "from_date must be on or before to_date" if @from_date > @to_date
    end

    def call
      appointments = Appointment.where(
        health_facility_id: @health_facility_id,
        scheduled_at: @from_date.beginning_of_day..@to_date.end_of_day,
        status: COUNTED_STATUSES
      )

      status_counts = appointments.group(:status).count
      total = status_counts.values.sum
      completed = status_counts.fetch("completed", 0)
      no_show = status_counts.fetch("no_show", 0)
      cancelled = status_counts.fetch("cancelled", 0)
      attended = completed + status_counts.fetch("checked_in", 0) + status_counts.fetch("in_progress", 0)

      slot_scope = RoomCapacitySlot.where(
        health_facility_id: @health_facility_id,
        slot_date: @from_date..@to_date
      )
      slot_capacity = slot_scope.sum(:capacity)
      slot_booked = slot_scope.sum(:booked_count)

      {
        from_date: @from_date,
        to_date: @to_date,
        total_appointments: total,
        status_counts: status_counts,
        completed_count: completed,
        no_show_count: no_show,
        cancelled_count: cancelled,
        attended_count: attended,
        no_show_rate: rate(no_show, total),
        completion_rate: rate(completed, total),
        slot_capacity_total: slot_capacity,
        slot_booked_total: slot_booked,
        slot_utilization_rate: rate(slot_booked, slot_capacity)
      }
    end

    private

    def rate(numerator, denominator)
      return 0.0 if denominator.zero?

      ((numerator.to_f / denominator) * 100).round(2)
    end
  end
end

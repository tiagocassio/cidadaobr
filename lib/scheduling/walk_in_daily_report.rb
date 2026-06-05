# frozen_string_literal: true

module Scheduling
  class WalkInDailyReport
    Result = Data.define(:date, :total, :by_service_type, :by_room)

    def initialize(health_facility_id:, date: Date.current)
      @health_facility_id = health_facility_id
      @date = date
    end

    def call
      scope = Appointment.where(
        health_facility_id: @health_facility_id,
        kind: "walk_in",
        scheduled_at: @date.all_day
      )

      Result.new(
        date: @date,
        total: scope.count,
        by_service_type: scope.joins(:appointment_service_type).group("appointment_service_types.name").count,
        by_room: scope.joins(:consultation_room).group("consultation_rooms.name").count
      )
    end
  end
end

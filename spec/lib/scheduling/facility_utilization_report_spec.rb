# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scheduling::FacilityUtilizationReport do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let!(:citizen) do
    with_tenant(membership) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end
  let!(:service_type) do
    with_tenant(membership) do
      AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
    end
  end
  let!(:room) do
    with_tenant(membership) do
      ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
    end
  end

  def book_on(day, status: "scheduled", hour: 9)
    with_tenant(membership) do
      starts = format("%02d:00", hour)
      ends = format("%02d:20", hour)
      slot = RoomCapacitySlot.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        slot_date: day,
        starts_at: starts,
        ends_at: ends,
        capacity: 2,
        booked_count: 0
      )
      appt = Appointment.create!(
        municipality: municipality,
        health_facility: facility,
        consultation_room: room,
        appointment_service_type: service_type,
        citizen: citizen,
        care_team: team,
        scheduled_at: day.to_time.change(hour: hour),
        status: status,
        kind: "scheduled",
        channel: "web_reception",
        modality: "presential",
        duration_minutes: 30
      )
      slot.update!(booked_count: 1)
      appt
    end
  end

  it "aggregates no_show and utilization for a date range" do
    day = Date.current
    with_tenant(membership) do
      book_on(day, status: "completed", hour: 9)
      book_on(day, status: "no_show", hour: 10)
      book_on(day + 1.day, status: "cancelled", hour: 9)

      report = described_class.new(
        health_facility_id: facility.id,
        from_date: day,
        to_date: day + 1.day
      ).call

      expect(report[:total_appointments]).to eq(3)
      expect(report[:no_show_count]).to eq(1)
      expect(report[:completed_count]).to eq(1)
      expect(report[:cancelled_count]).to eq(1)
      expect(report[:no_show_rate]).to eq(33.33)
      expect(report[:slot_booked_total]).to be >= 3
    end
  end
end

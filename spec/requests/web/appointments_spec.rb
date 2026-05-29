# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web appointments", type: :request do
  context "with multiple facilities" do
    let(:municipality) { create(:municipality) }
    let(:facility_a) { create(:health_facility, municipality: municipality, name: "UBS A") }
    let(:facility_b) { create(:health_facility, municipality: municipality, name: "UBS B") }
    let(:municipal_membership) do
      create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
    end

    before do
      facility_a
      facility_b
      sign_in_web(user: municipal_membership.user, membership: municipal_membership)
    end

    it "asks municipal users to pick a UBS when several facilities exist" do
      get web_appointments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Selecione a UBS")
      expect(response.body).to include("UBS A")
      expect(response.body).to include("UBS B")
    end

    it "loads the schedule when health_facility_id is provided" do
      get web_appointments_path(health_facility_id: facility_a.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agenda UBS")
      expect(response.body).not_to include("Selecione a UBS")
    end

    it "loads the utilization report" do
      get utilization_web_appointments_path(health_facility_id: facility_a.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("cidadaobr.appointments.utilization_title"))
    end

    it "preserves health_facility_id on the new appointment form" do
      get new_web_appointment_path(health_facility_id: facility_a.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("health_facility_id=#{facility_a.id}")
    end
  end

  context "when the municipality has a single facility" do
    let(:municipality) { create(:municipality) }
    let!(:only_facility) { create(:health_facility, municipality: municipality, name: "UBS Única") }
    let(:municipal_membership) do
      create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
    end

    before { sign_in_web(user: municipal_membership.user, membership: municipal_membership) }

    it "redirects municipal users automatically" do
      get web_appointments_path

      expect(response).to redirect_to(web_appointments_path(health_facility_id: only_facility.id))
    end
  end

  context "with team-scoped reception access" do
    let(:municipality) { create(:municipality) }
    let(:facility) { create(:health_facility, municipality: municipality) }
    let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
    let(:team_user) { create(:user) }
    let(:team_membership) do
      create(:user_team_assignment, user: team_user, care_team: team)
      create(
        :user_municipality_membership,
        user: team_user,
        municipality: municipality,
        scope: "team",
        role_code: "community_agent"
      )
    end
    let!(:service_type) do
      with_tenant(team_membership) do
        AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
      end
    end
    let!(:room) do
      with_tenant(team_membership) do
        ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
      end
    end
    let!(:capacity_slot) do
      with_tenant(team_membership) do
        RoomCapacitySlot.create!(
          municipality: municipality,
          health_facility: facility,
          consultation_room: room,
          slot_date: Date.current,
          starts_at: "09:00",
          ends_at: "09:20",
          capacity: 1,
          booked_count: 0
        )
      end
    end
    let!(:citizen) do
      with_tenant(team_membership) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      end
    end
    let!(:appointment) do
      with_tenant(team_membership) do
        Scheduling::BookAppointment.call(
          citizen_id: citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
          room_capacity_slot_id: capacity_slot.id,
          care_team_id: team.id
        )
      end
    end

    before { sign_in_web(user: team_user, membership: team_membership) }

    it "allows team users to check in from reception" do
      post check_in_web_appointment_path(appointment, health_facility_id: facility.id)

      expect(response).to redirect_to(reception_web_appointments_path(health_facility_id: facility.id))
      expect(with_tenant(team_membership) { appointment.reload.status }).to eq("checked_in")
    end

    it "marks no-show from reception and releases the slot" do
      post no_show_web_appointment_path(appointment, health_facility_id: facility.id)

      expect(response).to redirect_to(reception_web_appointments_path(health_facility_id: facility.id))
      with_tenant(team_membership) do
        expect(appointment.reload.status).to eq("no_show")
        expect(capacity_slot.reload.booked_count).to eq(0)
      end
    end

    it "marks no-show from in_progress at reception" do
      with_tenant(team_membership) { appointment.update!(status: "in_progress") }

      post no_show_web_appointment_path(appointment, health_facility_id: facility.id)

      expect(response).to redirect_to(reception_web_appointments_path(health_facility_id: facility.id))
      expect(with_tenant(team_membership) { appointment.reload.status }).to eq("no_show")
    end

    it "loads reception without health_facility_id when team has a single facility" do
      get reception_web_appointments_path

      expect(response).to redirect_to(reception_web_appointments_path(health_facility_id: facility.id))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(citizen.full_name)
    end

    it "blocks team users from creating appointments" do
      get new_web_appointment_path(health_facility_id: facility.id)

      expect(response).to redirect_to(web_root_path)
    end
  end

  context "with facility manager reschedule access" do
    let(:municipality) { create(:municipality) }
    let(:facility) { create(:health_facility, municipality: municipality) }
    let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
    let(:facility_manager) do
      create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility", role_code: "facility_manager")
    end
    let!(:service_type) do
      with_tenant(facility_manager) do
        AppointmentServiceType.create!(municipality: municipality, code: "medical_consultation", name: "Consulta")
      end
    end
    let!(:room) do
      with_tenant(facility_manager) do
        ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 1", room_kind: "general")
      end
    end
    let!(:morning_slot) do
      with_tenant(facility_manager) do
        RoomCapacitySlot.create!(
          municipality: municipality,
          health_facility: facility,
          consultation_room: room,
          slot_date: Date.current,
          starts_at: "09:00",
          ends_at: "09:20",
          capacity: 1,
          booked_count: 0
        )
      end
    end
    let!(:later_slot) do
      with_tenant(facility_manager) do
        RoomCapacitySlot.create!(
          municipality: municipality,
          health_facility: facility,
          consultation_room: room,
          slot_date: Date.current,
          starts_at: "10:00",
          ends_at: "10:20",
          capacity: 1,
          booked_count: 0
        )
      end
    end
    let!(:other_room) do
      with_tenant(facility_manager) do
        ConsultationRoom.create!(municipality: municipality, health_facility: facility, name: "Sala 2", room_kind: "general")
      end
    end
    let!(:other_room_slot) do
      with_tenant(facility_manager) do
        RoomCapacitySlot.create!(
          municipality: municipality,
          health_facility: facility,
          consultation_room: other_room,
          slot_date: Date.current,
          starts_at: "11:00",
          ends_at: "11:20",
          capacity: 1,
          booked_count: 0
        )
      end
    end
    let!(:citizen) do
      with_tenant(facility_manager) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      end
    end
    let!(:another_citizen) do
      with_tenant(facility_manager) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Maria Silva")
      end
    end
    let!(:appointment) do
      with_tenant(facility_manager) do
        Scheduling::BookAppointment.call(
          citizen_id: citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          scheduled_at: Time.zone.parse("#{Date.current} 09:00"),
          room_capacity_slot_id: morning_slot.id,
          channel: "web_reception"
        )
      end
    end

    before { sign_in_web(user: facility_manager.user, membership: facility_manager) }

    it "reschedules an appointment to another slot in the same room" do
      post reschedule_web_appointment_path(appointment), params: { room_capacity_slot_id: later_slot.id }

      expect(response).to redirect_to(web_appointment_path(appointment))
      follow_redirect!
      expect(response.body).to include("Consulta reagendada")

      with_tenant(facility_manager) do
        expect(appointment.reload.scheduled_at).to eq(Time.zone.parse("#{Date.current} 10:00"))
        expect(appointment.appointment_room_slot.room_capacity_slot_id).to eq(later_slot.id)
      end
    end

    it "does not offer slots from another room on the appointment page" do
      get web_appointment_path(appointment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(later_slot.starts_at.strftime("%H:%M"))
      expect(response.body).not_to include("Sala 2")
    end

    it "rejects reschedule to a slot in another room" do
      post reschedule_web_appointment_path(appointment), params: { room_capacity_slot_id: other_room_slot.id }

      expect(response).to redirect_to(web_appointment_path(appointment))
      follow_redirect!
      expect(response.body).to include("Dados inválidos para reagendamento")

      with_tenant(facility_manager) do
        expect(appointment.reload.scheduled_at).to eq(Time.zone.parse("#{Date.current} 09:00"))
        expect(appointment.appointment_room_slot.room_capacity_slot_id).to eq(morning_slot.id)
      end
    end

    it "shows a translated flash when booking a full slot" do
      post web_appointments_path(health_facility_id: facility.id), params: {
        appointment: {
          citizen_id: another_citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          room_capacity_slot_id: morning_slot.id,
          care_team_id: team.id
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("cidadaobr.scheduling.slot_unavailable.slot_full"))
    end

    it "shows a translated flash when rescheduling to a full slot" do
      with_tenant(facility_manager) do
        Scheduling::BookAppointment.call(
          citizen_id: another_citizen.id,
          appointment_service_type_id: service_type.id,
          consultation_room_id: room.id,
          scheduled_at: Time.zone.parse("#{Date.current} 10:00"),
          room_capacity_slot_id: later_slot.id,
          channel: "web_reception"
        )
      end

      post reschedule_web_appointment_path(appointment), params: { room_capacity_slot_id: later_slot.id }

      expect(response).to redirect_to(web_appointment_path(appointment))
      follow_redirect!
      expect(response.body).to include(I18n.t("cidadaobr.scheduling.slot_unavailable.slot_full"))
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Citizen API OpenAPI contract (Fase 3)" do
  let(:openapi) { YAML.load_file(Rails.root.join("doc/api/openapi.v1.yaml")) }
  let(:documented_paths) { openapi.fetch("paths").keys }
  let(:schemas) { openapi.fetch("components").fetch("schemas") }

  it "documents all citizen routes implemented in Rails" do
    expected = %w[
      /api/v1/citizen/health
      /api/v1/citizen/auth
      /api/v1/citizen/appointments
      /api/v1/citizen/appointments/slots
      /api/v1/citizen/appointments/{id}/cancel
      /api/v1/citizen/appointments/{id}/reschedule
      /api/v1/citizen/immunization_records
    ]

    expect(documented_paths).to include(*expected)
  end

  it "documents immunization wallet shape (not a bare array)" do
    schema = schemas.fetch("ImmunizationWallet")
    expect(schema.fetch("properties")).to include("records", "applied_records_percent")
    get_op = openapi.dig("paths", "/api/v1/citizen/immunization_records", "get", "responses", "200", "content", "application/json", "schema")
    expect(get_op.fetch("$ref")).to eq("#/components/schemas/ImmunizationWallet")
  end

  it "ImmunizationRecord properties match index.json.jbuilder" do
    props = schemas.fetch("ImmunizationRecord").fetch("properties").keys
    expect(props).to match_array(%w[vaccine_code vaccine_name dose_label applied_on lot_number])
  end

  it "BookAppointmentRequest required fields match AppointmentsController#create params" do
    required = schemas.fetch("BookAppointmentRequest").fetch("required")
    expect(required).to match_array(
      %w[appointment_service_type_id consultation_room_id room_capacity_slot_id scheduled_at]
    )
  end

  it "RescheduleAppointmentRequest required fields match AppointmentsController#reschedule params" do
    required = schemas.fetch("RescheduleAppointmentRequest").fetch("required")
    expect(required).to match_array(%w[consultation_room_id room_capacity_slot_id scheduled_at])
  end

  it "Appointment schema documents service (legacy service_type_name removed)" do
    props = schemas.fetch("Appointment").fetch("properties")
    expect(props).to include("service")
    expect(props).not_to include("service_type_name")
  end

  it "AppointmentSlot properties match slots.json.jbuilder" do
    props = schemas.fetch("AppointmentSlot").fetch("properties").keys
    expect(props).to match_array(
      %w[id consultation_room_id room_name starts_at ends_at remaining_capacity]
    )
  end

  it "documents slots GET query parameters required by AppointmentsController#slots" do
    params = openapi.dig("paths", "/api/v1/citizen/appointments/slots", "get", "parameters")
    expect(params.map { |p| p.fetch("name") }).to match_array(%w[health_facility_id date])
    params.each do |param|
      expect(param.fetch("in")).to eq("query")
      expect(param.fetch("required")).to be(true)
    end
  end

  it "documents vaccine booking via appointments POST request body" do
    post_op = openapi.dig("paths", "/api/v1/citizen/appointments", "post")
    expect(post_op.fetch("summary")).to include("vacina")
    schema_ref = post_op.dig("requestBody", "content", "application/json", "schema", "$ref")
    expect(schema_ref).to eq("#/components/schemas/BookAppointmentRequest")
  end
end

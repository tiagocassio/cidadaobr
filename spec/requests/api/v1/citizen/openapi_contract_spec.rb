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
      /api/v1/citizen/panic_alerts
      /api/v1/citizen/teleconsultation_sessions
      /api/v1/citizen/continuous_medications
    ]

    expect(documented_paths).to include(*expected)
  end

  def rails_api_paths(prefix)
    Rails.application.routes.routes.filter_map do |route|
      next unless route.verb.match?(/GET|POST|PUT|PATCH|DELETE/)

      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next unless path.start_with?(prefix)

      path.gsub(/:([\w]+)/, '{\1}')
    end.uniq.sort
  end

  it "documents every implemented citizen API route (bidirectional parity)" do
    documented_citizen_paths = documented_paths.select { |path| path.start_with?("/api/v1/citizen") }.sort

    expect(documented_citizen_paths).to match_array(rails_api_paths("/api/v1/citizen"))
  end

  it "documents every implemented reference API route (bidirectional parity)" do
    documented_reference_paths = documented_paths.select { |path| path.start_with?("/api/v1/reference") }.sort

    expect(documented_reference_paths).to match_array(rails_api_paths("/api/v1/reference"))
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

  it "PanicAlert properties match create.json.jbuilder" do
    props = schemas.fetch("PanicAlert").fetch("properties").keys
    expect(props).to match_array(%w[id status triggered_at])
  end

  it "documents panic POST 422 for validation errors" do
    responses = openapi.dig("paths", "/api/v1/citizen/panic_alerts", "post", "responses").keys
    expect(responses).to include("422")
  end

  it "TeleconsultationSession properties match teleconsultation jbuilders" do
    props = schemas.fetch("TeleconsultationSession").fetch("properties").keys
    expect(props).to match_array(%w[id status scheduled_at room_token])
  end

  it "documents teleconsultation POST 422" do
    responses = openapi.dig("paths", "/api/v1/citizen/teleconsultation_sessions", "post", "responses").keys
    expect(responses).to include("422")
  end

  it "ContinuousMedication properties match create.json.jbuilder" do
    props = schemas.fetch("ContinuousMedication").fetch("properties").keys
    expect(props).to match_array(%w[id medication_name dosage frequency started_on active])
  end

  it "documents continuous medications POST 422" do
    responses = openapi.dig("paths", "/api/v1/citizen/continuous_medications", "post", "responses").keys
    expect(responses).to include("422")
  end
end

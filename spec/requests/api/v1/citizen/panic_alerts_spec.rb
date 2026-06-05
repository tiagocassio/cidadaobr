# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Citizen panic alerts API", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
  let(:tenant_scope) do
    Cidadaobr::TenantScope.new(municipality_id: municipality.id, scope: "municipality", health_facility_id: nil, team_ids: [], citizen_id: nil)
  end
  let(:citizen) do
    with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
    end
  end
  let!(:account) do
    with_tenant(tenant_scope) do
      CitizenAccount.create!(municipality: municipality, citizen: citizen, cpf: citizen.cpf, password: "password123")
    end
  end
  let(:headers) { { "Authorization" => "Bearer #{JwtTokenService.encode_citizen(account: account)}" } }

  it "creates a panic alert" do
    post "/api/v1/citizen/panic_alerts",
         params: { latitude: -23.5, longitude: -46.6 },
         headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("panic_alert", "status")).to eq("triggered")

    citizen_scope = Cidadaobr::TenantScope.from_citizen_account(account)
    Cidadaobr::TenantContext.with(citizen_scope) do
      expect(PanicAlert.count).to eq(1)
      expect(DomainEvent.where(event_type: Cidadaobr::KafkaTopics::PANIC_ALERT_TRIGGERED).count).to eq(1)
      expect(OutboxMessage.where(event_type: Cidadaobr::KafkaTopics::PANIC_ALERT_TRIGGERED).count).to eq(1)
      event = DomainEvent.find_by(event_type: Cidadaobr::KafkaTopics::PANIC_ALERT_TRIGGERED)
      expect(event.care_team_id).to eq(team.id)
    end
  end

  it "returns unprocessable entity when trigger validation fails" do
    allow(CommandBus).to receive(:dispatch).and_wrap_original do |method, command, **kwargs|
      if command == CitizenPortal::Commands::TriggerPanicAlert
        raise ArgumentError, "citizen account does not match tenant scope"
      end

      method.call(command, **kwargs)
    end

    post "/api/v1/citizen/panic_alerts",
         params: { latitude: -23.5, longitude: -46.6 },
         headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to include("does not match tenant scope")
  end

  it "rejects citizen account that does not match tenant scope" do
    other_citizen = with_tenant(tenant_scope) do
      create(:citizen, municipality: municipality, health_facility: facility, care_team: team, cpf: "52998224725")
    end
    other_account = with_tenant(tenant_scope) do
      CitizenAccount.create!(municipality: municipality, citizen: other_citizen, cpf: other_citizen.cpf, password: "password123")
    end
    citizen_scope = Cidadaobr::TenantScope.from_citizen_account(account)

    expect {
      Cidadaobr::TenantContext.with(citizen_scope) do
        CitizenPortal::Commands::TriggerPanicAlert.call(citizen_account: other_account)
      end
    }.to raise_error(ArgumentError, /does not match tenant scope/)
  end

  it "returns unprocessable entity when panic alert is triggered too soon" do
    post "/api/v1/citizen/panic_alerts",
         params: { latitude: -23.5, longitude: -46.6 },
         headers: headers
    expect(response).to have_http_status(:ok)

    post "/api/v1/citizen/panic_alerts",
         params: { latitude: -23.51, longitude: -46.61 },
         headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to include("already triggered recently")
  end
end

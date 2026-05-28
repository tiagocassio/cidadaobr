# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API auth endpoints", type: :request do
  let(:municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }

  describe "POST /api/v1/field/auth" do
    let(:user) { create(:user, email: "field@example.com", password: "password123", password_confirmation: "password123") }
    let!(:membership) do
      create(
        :user_municipality_membership,
        user: user,
        municipality: municipality,
        health_facility: facility,
        scope: "facility",
        role_code: "community_agent"
      )
    end

    it "returns token and membership context" do
      post "/api/v1/field/auth", params: {
        email: user.email,
        password: "password123",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include(
        "token" => kind_of(String),
        "scope" => "facility",
        "municipality_id" => municipality.id,
        "health_facility_id" => facility.id
      )
    end

    it "returns unauthorized for invalid credentials" do
      post "/api/v1/field/auth", params: {
        email: user.email,
        password: "wrong-password",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid credentials")
    end
  end

  describe "POST /api/v1/citizen/auth" do
    let(:facility) { create(:health_facility, municipality: municipality) }
    let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }
    let(:tenant_scope) do
      Cidadaobr::TenantScope.new(municipality_id: municipality.id, scope: "municipality", health_facility_id: nil, team_ids: [], citizen_id: nil)
    end
    let(:citizen) do
      with_tenant(tenant_scope) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, cpf: "39053344705")
      end
    end
    let!(:account) do
      with_tenant(tenant_scope) do
        CitizenAccount.create!(municipality: municipality, citizen: citizen, cpf: citizen.cpf, password: "password123")
      end
    end

    it "returns token and citizen context" do
      post "/api/v1/citizen/auth", params: {
        cpf: citizen.cpf,
        password: "password123",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include(
        "token" => kind_of(String),
        "scope" => "citizen",
        "municipality_id" => municipality.id,
        "citizen_id" => citizen.id
      )
    end

    it "returns unauthorized for invalid credentials" do
      post "/api/v1/citizen/auth", params: {
        cpf: citizen.cpf,
        password: "wrong-password",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid credentials")
    end

    it "returns unprocessable entity for invalid municipality_id" do
      post "/api/v1/citizen/auth", params: {
        cpf: citizen.cpf,
        password: "password123",
        municipality_id: "not-a-uuid"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid municipality_id")
    end

    it "returns unauthorized for malformed cpf without hitting the database" do
      post "/api/v1/citizen/auth", params: {
        cpf: "123",
        password: "password123",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid credentials")
    end
  end
end

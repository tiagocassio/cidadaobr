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
    let(:user) { create(:user, email: "citizen@example.com", password: "password123", password_confirmation: "password123") }
    let!(:membership) do
      create(
        :user_municipality_membership,
        user: user,
        municipality: municipality,
        scope: "municipality",
        role_code: "municipal_admin"
      )
    end

    it "returns token and membership context" do
      post "/api/v1/citizen/auth", params: {
        email: user.email,
        password: "password123",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include(
        "token" => kind_of(String),
        "scope" => "municipality",
        "municipality_id" => municipality.id
      )
      expect(body).not_to have_key("health_facility_id")
    end

    it "returns unauthorized for invalid credentials" do
      post "/api/v1/citizen/auth", params: {
        email: user.email,
        password: "wrong-password",
        municipality_id: municipality.id
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq("error" => "Invalid credentials")
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API health endpoints", type: :request do
  describe "GET /api/v1/field/health" do
    it "returns ok" do
      get "/api/v1/field/health"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("channel" => "field")
    end
  end

  describe "GET /api/v1/citizen/health" do
    it "returns ok" do
      get "/api/v1/citizen/health"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("channel" => "citizen")
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reference API", type: :request do
  let(:municipality) { create(:municipality) }
  let(:membership) { create(:user_municipality_membership, municipality: municipality, scope: "municipality") }
  let(:headers) { auth_headers_for(membership) }

  before do
    Reference::DomainSeedImporter.call
    Reference::PublishRelease.call
  end

  it "requires authentication" do
    get "/api/v1/reference/manifest"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns manifest" do
    get "/api/v1/reference/manifest", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["domains"]).to be_present
    expect(response.headers["ETag"]).to be_present
  end

  it "returns domain entries" do
    get "/api/v1/reference/domains/ciap2", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["entries"].size).to be >= 1
  end

  it "loads vendor reference fixtures when present" do
    expect(Reference::DomainSeedImporter.source_path.to_s).to include("vendor/reference/domains.yml")

    get "/api/v1/reference/domains/sigtap_procedure", headers: headers

    expect(response).to have_http_status(:ok)
    codes = response.parsed_body["entries"].map { |entry| entry["code"] }
    expect(codes).to include("0301100039")
  end

  it "returns ledi catalog fields" do
    get "/api/v1/reference/ledi/catalog", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("ledi_version", "fields")
  end
end

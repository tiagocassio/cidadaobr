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
end

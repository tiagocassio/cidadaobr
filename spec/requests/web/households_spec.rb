# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web households markers", type: :request do
  let(:municipality) { create(:municipality) }
  let(:membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before { sign_in_web(user: membership.user, membership: membership) }

  it "returns no markers when bbox params are invalid" do
    get markers_web_households_path(format: :json), params: {
      sw_lat: 999,
      sw_lng: -46.65,
      ne_lat: -23.52,
      ne_lng: -46.61
    }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
  end

  it "returns no markers when bbox params are missing" do
    get markers_web_households_path(format: :json)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq([])
  end
end

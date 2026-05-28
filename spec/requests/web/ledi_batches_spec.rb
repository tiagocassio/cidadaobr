# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web ledi batches", type: :request do
  let(:municipality) { create(:municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  it "ignores invalid status filters" do
    get web_ledi_batches_path, params: { status: "invalid_status" }

    expect(response).to have_http_status(:ok)
  end
end

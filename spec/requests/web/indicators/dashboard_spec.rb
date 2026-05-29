# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web indicators", type: :request do
  let(:municipality) { create(:municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  it "loads the dashboard" do
    get web_indicators_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("cidadaobr.indicators.dashboard.title"))
  end

  it "loads the transfer projection page" do
    get web_indicators_projections_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("cidadaobr.indicators.projections.title"))
  end

  it "falls back to the current quadrimester for invalid filters" do
    get web_indicators_root_path, params: { quadrimester: "invalid" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(Indicators::Quadrimester.current)
  end

  context "with a facility manager" do
    let(:facility) { create(:health_facility, municipality: municipality) }
    let(:facility_membership) do
      create(:user_municipality_membership, municipality: municipality, health_facility: facility, scope: "facility", role_code: "facility_manager")
    end

    before { sign_in_web(user: facility_membership.user, membership: facility_membership) }

    it "shows scoped average copy instead of municipal wording" do
      get web_indicators_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("cidadaobr.indicators.dashboard.scoped_average"))
      expect(response.body).to include(I18n.t("cidadaobr.indicators.dashboard.scoped_score"))
      expect(response.body).not_to include(I18n.t("cidadaobr.indicators.dashboard.municipal_score"))
    end

    it "loads team drill-down" do
      team = create(:care_team, municipality: municipality, health_facility: facility)

      get web_indicators_team_path(team)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(team.name)
    end

    it "blocks transfer projections" do
      get web_indicators_projections_path

      expect(response).to redirect_to(web_root_path)
    end
  end
end

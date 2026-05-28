# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web pagination", type: :request do
  let(:municipality) { create(:municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:team) { create(:care_team, municipality: municipality, health_facility: facility) }

  before { sign_in_web(user: admin_membership.user, membership: admin_membership) }

  describe "citizens index" do
    it "finds citizens matching search across the full dataset" do
      with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
        50.times do |i|
          create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Common Name #{i}")
        end
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Zzz Unique Target")
      end

      get web_citizens_path, params: { q: "Zzz Unique" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Zzz Unique Target")
    end

    it "renders next page link when there are more than 50 citizens" do
      with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
        51.times do |i|
          create(:citizen, municipality: municipality, health_facility: facility, care_team: team, full_name: "Citizen #{i}")
        end
      end

      get web_citizens_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Próxima")
    end

    it "handles out-of-range page numbers" do
      with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
        create(:citizen, municipality: municipality, health_facility: facility, care_team: team)
      end

      get web_citizens_path, params: { page: 999 }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "households index" do
    it "renders next page link when there are more than 50 households" do
      with_tenant(Cidadaobr::TenantScope.from_membership(admin_membership)) do
        51.times do |i|
          Household.create!(
            municipality: municipality,
            health_facility: facility,
            care_team: team,
            ibge_code: municipality.ibge_code,
            street: "Rua #{i}"
          )
        end
      end

      get web_households_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Próxima")
    end
  end
end

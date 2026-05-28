# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Web users", type: :request do
  let(:municipality) { create(:municipality) }
  let(:other_municipality) { create(:municipality) }
  let(:facility) { create(:health_facility, municipality: municipality) }
  let(:foreign_facility) { create(:health_facility, municipality: other_municipality) }
  let(:admin_membership) do
    create(:user_municipality_membership, municipality: municipality, scope: "municipality", role_code: "municipal_admin")
  end

  it "creates user with municipality membership" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    expect {
      post web_users_path, params: {
        user: {
          email: "novo@example.com",
          full_name: "Novo Usuário",
          password: "password123",
          password_confirmation: "password123"
        },
        user_municipality_membership: {
          scope: "facility",
          role_code: "facility_manager",
          health_facility_id: facility.id
        }
      }
    }.to change(User, :count).by(1)
      .and change(UserMunicipalityMembership, :count).by(1)

    membership = User.find_by!(email: "novo@example.com").user_municipality_memberships.first
    expect(membership.health_facility_id).to eq(facility.id)
  end

  it "rejects foreign health facility on membership" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    expect {
      post web_users_path, params: {
        user: {
          email: "intruso@example.com",
          full_name: "Intruso",
          password: "password123",
          password_confirmation: "password123"
        },
        user_municipality_membership: {
          scope: "facility",
          role_code: "facility_manager",
          health_facility_id: foreign_facility.id
        }
      }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects team scope via crafted POST" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    expect {
      post web_users_path, params: {
        user: {
          email: "team@example.com",
          full_name: "Team User",
          password: "password123",
          password_confirmation: "password123"
        },
        user_municipality_membership: {
          scope: "team",
          role_code: "community_agent"
        }
      }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects unknown role codes via crafted POST" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    expect {
      post web_users_path, params: {
        user: {
          email: "badrole@example.com",
          full_name: "Bad Role",
          password: "password123",
          password_confirmation: "password123"
        },
        user_municipality_membership: {
          scope: "facility",
          role_code: "superadmin",
          health_facility_id: facility.id
        }
      }
    }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects deactivating the last municipal admin" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    patch web_user_path(admin_membership.user), params: {
      user: {
        email: admin_membership.user.email,
        full_name: admin_membership.user.full_name,
        active: false
      },
      user_municipality_membership: {
        scope: "municipality",
        role_code: "municipal_admin",
        active: true
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(admin_membership.user.reload).to be_active
  end

  it "rejects demoting the last municipal admin to facility scope" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    patch web_user_path(admin_membership.user), params: {
      user: {
        email: admin_membership.user.email,
        full_name: admin_membership.user.full_name,
        active: true
      },
      user_municipality_membership: {
        scope: "facility",
        role_code: "facility_manager",
        health_facility_id: facility.id,
        active: true
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(admin_membership.reload.scope).to eq("municipality")
  end

  it "ignores inactive membership flag on create" do
    sign_in_web(user: admin_membership.user, membership: admin_membership)

    post web_users_path, params: {
      user: {
        email: "inactive@example.com",
        full_name: "Inactive Admin",
        password: "password123",
        password_confirmation: "password123"
      },
      user_municipality_membership: {
        scope: "municipality",
        role_code: "municipal_admin",
        active: false
      }
    }

    membership = User.find_by!(email: "inactive@example.com").user_municipality_memberships.first
    expect(response).to redirect_to(web_users_path)
    expect(membership.active).to be(true)
  end
end

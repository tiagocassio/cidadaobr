# frozen_string_literal: true

FactoryBot.define do
  factory :municipality do
    sequence(:name) { |n| "Municipality #{n}" }
    sequence(:ibge_code) { |n| format("%07d", 1000000 + n) }
    state_code { "SP" }
  end

  factory :health_facility do
    municipality
    sequence(:name) { |n| "UBS #{n}" }
    sequence(:cnes) { |n| format("%07d", 2000000 + n) }
    facility_service_kind { "primary_care" }
  end

  factory :role do
    sequence(:name) { |n| "Role #{n}" }
    sequence(:code) { |n| "role_#{n}" }
  end

  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    full_name { "Test User" }
    password { "password123" }
    password_confirmation { "password123" }
    active { true }
  end

  factory :user_municipality_membership do
    user
    municipality
    scope { "municipality" }
    role_code { "municipal_admin" }
    active { true }
  end

  factory :care_team do
    municipality
    health_facility
    sequence(:ine) { |n| format("%010d", 3000000000 + n) }
    sequence(:name) { |n| "Equipe #{n}" }
  end

  factory :user_team_assignment do
    user
    care_team
    active { true }
  end
end

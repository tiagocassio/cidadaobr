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

  factory :citizen do
    municipality
    health_facility
    care_team
    sequence(:cpf) { |n| format("%011d", 39053344700 + n) }
    sequence(:full_name) { |n| "Citizen #{n}" }
  end

  factory :user_team_assignment do
    user
    care_team
    active { true }
  end

  factory :micro_area do
    municipality
    care_team
    sequence(:code) { |n| format("%02d", n) }
    sequence(:name) { |n| "Microárea #{n}" }
    coverage do
      factory = Cidadaobr::GeoPoint.factory
      ring = factory.linear_ring([
        factory.point(-46.65, -23.58),
        factory.point(-46.61, -23.58),
        factory.point(-46.61, -23.52),
        factory.point(-46.65, -23.52),
        factory.point(-46.65, -23.58)
      ])
      factory.polygon(ring)
    end
  end

  factory :facility_micro_area_coverage do
    health_facility
    micro_area
  end

  factory :household_animal do
    household
    species { "cão" }
    quantity { 1 }
  end
end

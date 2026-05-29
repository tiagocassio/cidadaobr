# frozen_string_literal: true

FactoryBot.define do
  module TenantFactoryHelpers
    module_function

    def save_with_municipality_tenant!(instance)
      scope = Cidadaobr::TenantScope.new(
        municipality_id: instance.municipality_id,
        scope: "municipality",
        health_facility_id: nil,
        team_ids: [],
        citizen_id: nil
      )
      Cidadaobr::TenantContext.with(scope) { instance.save! }
    end
  end

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

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
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

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
  end

  factory :care_team do
    municipality
    health_facility
    team_kind { "esf" }
    sequence(:ine) { |n| format("%010d", 3000000000 + n) }
    sequence(:name) { |n| "Equipe #{n}" }

    trait :esb do
      team_kind { "esb" }
    end

    trait :emulti do
      team_kind { "emulti" }
    end

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
  end

  factory :citizen do
    municipality
    health_facility { association :health_facility, municipality: municipality }
    care_team { association :care_team, municipality: municipality, health_facility: health_facility }
    sequence(:cpf) { |n| Cidadaobr::Cpf.generate(39_053_344 + n) }
    sequence(:full_name) { |n| "Citizen #{n}" }

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
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

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
  end

  factory :facility_micro_area_coverage do
    health_facility
    micro_area
  end

  factory :ledi_batch do
    municipality
    sequence(:batch_number) { |n| n + 1 }
    ledi_version { "6.3.5" }
    status { "ready" }

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
  end

  factory :household do
    municipality
    health_facility { association :health_facility, municipality: municipality }
    care_team { association :care_team, municipality: municipality, health_facility: health_facility }
    ibge_code { municipality.ibge_code }
    street { "Rua das Flores" }
    sequence(:street_number) { |n| n.to_s }
    neighborhood { "Centro" }
    location do
      factory = Cidadaobr::GeoPoint.factory
      factory.point(-46.63, -23.55)
    end

    to_create { |instance| TenantFactoryHelpers.save_with_municipality_tenant!(instance) }
  end

  factory :household_member do
    household
    citizen
    family_reference { false }
  end

  factory :household_animal do
    household
    species { "cão" }
    quantity { 1 }
  end
end

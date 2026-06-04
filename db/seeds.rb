# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment.
municipality = Municipality.find_or_create_by!(ibge_code: "3550308") do |record|
  record.name = "São Paulo"
  record.state_code = "SP"
end

municipality_tenant = Cidadaobr::TenantScope.new(
  municipality_id: municipality.id,
  scope: "municipality",
  health_facility_id: nil,
  team_ids: [],
  citizen_id: nil
)

facility_a = nil
facility_b = nil
team_centro = nil
team_norte = nil
team_esb_centro = nil
team_emulti_norte = nil

ActiveRecord::Base.transaction do
  Cidadaobr::TenantContext.with(municipality_tenant) do
    facility_a = HealthFacility.find_or_initialize_by(municipality: municipality, cnes: "2000001")
    facility_a.assign_attributes(
      name: "UBS Centro",
      facility_service_kind: "primary_care",
      location: Cidadaobr::GeoPoint.build(lng: -42.78238676865467, lat: -5.147343336515128)
    )
    facility_a.save!

    facility_b = HealthFacility.find_or_initialize_by(municipality: municipality, cnes: "2000002")
    facility_b.assign_attributes(
      name: "UBS Norte",
      facility_service_kind: "primary_care",
      location: Cidadaobr::GeoPoint.build(lng: -42.759083736490716, lat: -5.0489857982207536)
    )
    facility_b.save!

    team_centro = CareTeam.find_or_initialize_by(municipality: municipality, ine: "0000000001")
    team_centro.assign_attributes(name: "Equipe Centro 01", health_facility: facility_a, team_kind: "esf")
    team_centro.save!

    team_norte = CareTeam.find_or_initialize_by(municipality: municipality, ine: "0000000002")
    team_norte.assign_attributes(name: "Equipe Norte 01", health_facility: facility_b, team_kind: "esf")
    team_norte.save!

    team_esb_centro = CareTeam.find_or_initialize_by(municipality: municipality, ine: "0000000003")
    team_esb_centro.assign_attributes(name: "Equipe Saúde Bucal Centro", health_facility: facility_a, team_kind: "esb")
    team_esb_centro.save!

    team_emulti_norte = CareTeam.find_or_initialize_by(municipality: municipality, ine: "0000000004")
    team_emulti_norte.assign_attributes(name: "Equipe eMulti Norte", health_facility: facility_b, team_kind: "emulti")
    team_emulti_norte.save!

    micro_area = MicroArea.find_or_initialize_by(municipality: municipality, code: "01")
    factory = Cidadaobr::GeoPoint.factory
    ring = factory.linear_ring([
      factory.point(-42.792, -5.157),
      factory.point(-42.772, -5.157),
      factory.point(-42.772, -5.137),
      factory.point(-42.792, -5.137),
      factory.point(-42.792, -5.157)
    ])
    micro_area.assign_attributes(
      name: "Microárea Centro",
      care_team: team_centro,
      coverage: factory.polygon(ring)
    )
    micro_area.save!

    FacilityMicroAreaCoverage.find_or_create_by!(health_facility: facility_a, micro_area: micro_area)

    Installation.find_or_create_by!(municipality: municipality, counter_key: "dev") do |record|
      record.installation_uuid = Rails.application.config.ledi.fetch(:dev_installation_uuid)
      record.tax_id = "39053344705"
      record.legal_name = "CidadãoBR Dev"
    end
  end
end

admin_role = Role.find_or_create_by!(code: "municipal_admin") do |record|
  record.name = "Administrador Municipal"
end

admin = User.find_or_initialize_by(email: "admin@cidadaobr.local")
admin.assign_attributes(full_name: "Administrador Municipal", password: "password123", password_confirmation: "password123", active: true)
admin.save!

UserRole.find_or_create_by!(user: admin, role: admin_role)

UserMunicipalityMembership.find_or_create_by!(user: admin, municipality: municipality, health_facility: nil) do |record|
  record.scope = "municipality"
  record.role_code = "municipal_admin"
  record.active = true
end

facility_manager = User.find_or_initialize_by(email: "ubs.centro@cidadaobr.local")
facility_manager.assign_attributes(full_name: "Gestor UBS Centro", password: "password123", password_confirmation: "password123", active: true)
facility_manager.save!

UserMunicipalityMembership.find_or_create_by!(user: facility_manager, municipality: municipality, health_facility: facility_a) do |record|
  record.scope = "facility"
  record.role_code = "facility_manager"
  record.active = true
end

puts "Seed complete:"
puts "  Municipality ID: #{municipality.id}"
puts "  Admin login: admin@cidadaobr.local / password123"
puts "  UBS Centro login: ubs.centro@cidadaobr.local / password123"

ActiveRecord::Base.transaction do
  Cidadaobr::TenantContext.with(municipality_tenant) do
    micro_area = MicroArea.find_by!(municipality: municipality, code: "01")
    puts "  Care teams: #{team_centro.name} (#{team_centro.team_kind}), #{team_norte.name} (#{team_norte.team_kind})"
    puts "  Demo B/M teams: #{team_esb_centro.name} (#{team_esb_centro.team_kind}), #{team_emulti_norte.name} (#{team_emulti_norte.team_kind})"
    puts "  Microárea demo: #{micro_area.code} - #{micro_area.name}"
    puts "  UBS Centro: lat -5.147343, lng -42.782387"
    puts "  UBS Norte: lat -5.048986, lng -42.759084"
  end
end

ActiveRecord::Base.transaction do
  Cidadaobr::TenantContext.with(municipality_tenant) do
    load Rails.root.join("db/seeds/ledi_catalog.rb")
    load Rails.root.join("db/seeds/indicator_catalog.rb")
    load Rails.root.join("db/seeds/reference/pni_calendar.rb")
    load Rails.root.join("db/seeds/inventory_and_campaigns.rb")
  end
end

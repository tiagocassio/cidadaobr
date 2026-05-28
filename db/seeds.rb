# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment.
municipality = Municipality.find_or_create_by!(ibge_code: "3550308") do |record|
  record.name = "São Paulo"
  record.state_code = "SP"
end

facility_a = HealthFacility.find_or_create_by!(municipality: municipality, cnes: "2000001") do |record|
  record.name = "UBS Centro"
end

facility_b = HealthFacility.find_or_create_by!(municipality: municipality, cnes: "2000002") do |record|
  record.name = "UBS Norte"
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

Installation.find_or_create_by!(municipality: municipality, counter_key: "dev") do |record|
  record.installation_uuid = Rails.application.config.ledi.fetch(:dev_installation_uuid)
  record.tax_id = "39053344705"
  record.legal_name = "CidadãoBR Dev"
end

load Rails.root.join("db/seeds/ledi_catalog.rb")

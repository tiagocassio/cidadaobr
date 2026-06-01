# frozen_string_literal: true

municipality = Municipality.find_by!(ibge_code: "3550308")
facility_a = HealthFacility.find_by(municipality: municipality, cnes: "2000001")

unless facility_a
  puts "  Inventory seed skipped: UBS Centro (CNES 2000001) not visible in tenant scope"
  return
end

influenza = ImmunobiologicalProduct.find_or_initialize_by(municipality: municipality, code: "FLU4V")
influenza.assign_attributes(name: "Influenza tetravalente", target_species: "human", active: true)
influenza.save!

syringe = SupplyItem.find_or_initialize_by(municipality: municipality, code: "SYRINGE_05")
syringe.assign_attributes(name: "Seringa 0,5 ml", unit: "unit", active: true)
syringe.save!

lot = ImmunobiologicalLot.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  immunobiological_product: influenza,
  lot_number: "DEMO-2026-01"
)
lot.assign_attributes(expires_on: 1.year.from_now.to_date, manufacturer: "Demo Lab", quantity_on_hand: 500)
lot.save!

StockBalance.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  immunobiological_lot: lot
).update!(quantity: lot.quantity_on_hand)

StockBalance.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  supply_item: syringe
).update!(quantity: 1_000)

visit_kit = SupplyItem.find_or_initialize_by(municipality: municipality, code: "VISIT_KIT")
visit_kit.assign_attributes(name: "Kit visita domiciliar", unit: "kit", active: true)
visit_kit.save!

HealthFacility.where(municipality: municipality).find_each do |facility|
  StockBalance.find_or_initialize_by(
    municipality: municipality,
    health_facility: facility,
    supply_item: visit_kit
  ).update!(quantity: 500)
end

vaccination_room = ConsultationRoom.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  name: "Sala Vacinação"
)
vaccination_room.assign_attributes(room_kind: "vaccination", active: true)
vaccination_room.save!

starts_on = Date.current
ends_on = starts_on + 6.days
(starts_on..ends_on).each do |date|
  slot = RoomCapacitySlot.find_by(
    municipality: municipality,
    health_facility: facility_a,
    consultation_room: vaccination_room,
    slot_date: date
  )
  if slot
    slot.update!(capacity: 80, booked_count: 0)
  else
    RoomCapacitySlot.create!(
      municipality: municipality,
      health_facility: facility_a,
      consultation_room: vaccination_room,
      slot_date: date,
      starts_at: Time.zone.parse("#{date} 08:00"),
      ends_at: Time.zone.parse("#{date} 17:00"),
      capacity: 80,
      booked_count: 0
    )
  end
end

team_centro = CareTeam.find_by!(municipality: municipality, ine: "0000000001")
household = Household.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  street: "Rua Demo",
  street_number: "100"
)
household.assign_attributes(
  ibge_code: municipality.ibge_code,
  care_team: team_centro,
  micro_area_code: "01",
  neighborhood: "Centro",
  location: Cidadaobr::GeoPoint.build(lng: -46.6333, lat: -23.5505)
)
household.save!

[
  { cpf: "52998224725", name: "Maria Silva Demo", birth_date: 72.years.ago.to_date },
  { cpf: "39053344705", name: "João Santos Demo", birth_date: 45.years.ago.to_date },
  { cpf: "15350946056", name: "Ana Costa Demo", birth_date: 8.years.ago.to_date }
].each do |attrs|
  citizen = Citizen.find_or_initialize_by(municipality: municipality, cpf: attrs[:cpf])
  citizen.assign_attributes(
    care_team: team_centro,
    health_facility_id: nil,
    full_name: attrs[:name],
    birth_date: attrs[:birth_date],
    sex: "F"
  )
  citizen.save!
  HouseholdMember.find_or_create_by!(household: household, citizen: citizen)
end

puts "  Inventory seed: #{ImmunobiologicalProduct.count} products, #{ImmunobiologicalLot.count} lots, #{RoomCapacitySlot.count} capacity slots"
puts "  Demo citizens: #{Citizen.where(municipality: municipality).count} (UBS Centro; 2 elegíveis com min_idade 60)"

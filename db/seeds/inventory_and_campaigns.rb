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

syringe = SupplyItem.find_or_initialize_by(municipality: municipality, name: "Seringa 0,5 ml", kind: "simple")
syringe.assign_attributes(
  category: "syringe",
  sku: "SYRINGE-05",
  description: "Seringa descartável 0,5 ml — vacinação e medicação em domicílio",
  unit: "unit",
  active: true
)
syringe.save!

lancet = SupplyItem.find_or_initialize_by(municipality: municipality, name: "Lanceta", kind: "simple")
lancet.assign_attributes(
  category: "lancet",
  sku: "LANCET-01",
  description: "Lanceta descartável — glicemia capilar em visita domiciliar",
  unit: "unit",
  active: true
)
lancet.save!

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

StockBalance.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  supply_item: lancet
).update!(quantity: 1_000)

visit_kit = SupplyItem.find_or_initialize_by(municipality: municipality, name: "Kit visita domiciliar", kind: "composite")
visit_kit.assign_attributes(
  category: "visit_kit",
  sku: "VISIT-KIT",
  description: "Kit composto para visita domiciliar de campanha (seringa + lancetas por parada)",
  unit: "kit",
  active: true
)

[
  [ syringe, 1 ],
  [ lancet, 2 ]
].each do |component_item, quantity_per_unit|
  component = visit_kit.supply_item_components.find_or_initialize_by(component_item: component_item)
  component.municipality = municipality
  component.quantity_per_unit = quantity_per_unit
end

visit_kit.save!

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
demo_households = [
  {
    cpf: "52998224725",
    name: "Maria Silva Demo",
    birth_date: 72.years.ago.to_date,
    street_number: "100",
    lat: -5.169102301089202,
    lng: -42.77499377455036
  },
  {
    cpf: "39053344705",
    name: "João Santos Demo",
    birth_date: 45.years.ago.to_date,
    street_number: "120",
    lat: -5.190002213011813,
    lng: -42.756025191228396
  },
  {
    cpf: "15350946056",
    name: "Ana Costa Demo",
    birth_date: 8.years.ago.to_date,
    street_number: "140",
    lat: -5.1834630510838675,
    lng: -42.736412877845524
  }
]

demo_households.each do |attrs|
  household = Household.find_or_initialize_by(
    municipality: municipality,
    health_facility: facility_a,
    street: "Rua Demo",
    street_number: attrs[:street_number]
  )
  household.assign_attributes(
    ibge_code: municipality.ibge_code,
    care_team: team_centro,
    micro_area_code: "01",
    neighborhood: "Centro",
    location: Cidadaobr::GeoPoint.build(lng: attrs[:lng], lat: attrs[:lat])
  )
  household.save!

  citizen = Citizen.find_or_initialize_by(municipality: municipality, cpf: attrs[:cpf])
  citizen.assign_attributes(
    care_team: team_centro,
    health_facility_id: nil,
    full_name: attrs[:name],
    birth_date: attrs[:birth_date],
    sex: "F"
  )
  citizen.save!

  HouseholdMember.where(citizen: citizen).where.not(household: household).delete_all
  HouseholdMember.find_or_create_by!(household: household, citizen: citizen)
end

puts "  Inventory seed: #{ImmunobiologicalProduct.count} products, #{ImmunobiologicalLot.count} lots, #{RoomCapacitySlot.count} capacity slots"
puts "  Demo citizens: #{Citizen.where(municipality: municipality).count} (UBS Centro; 2 elegíveis com min_idade 60)"

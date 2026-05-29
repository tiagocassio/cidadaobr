# frozen_string_literal: true

municipality = Municipality.find_by!(ibge_code: "3550308")
facility_a = HealthFacility.find_by(municipality: municipality, cnes: "2000001")

unless facility_a
  puts "  Inventory seed skipped: UBS Centro (CNES 2000001) not visible in tenant scope"
  return
end

influenza = ImmunobiologicProduct.find_or_initialize_by(municipality: municipality, code: "FLU4V")
influenza.assign_attributes(name: "Influenza tetravalente", target_species: "human", active: true)
influenza.save!

syringe = SupplyItem.find_or_initialize_by(municipality: municipality, code: "SYRINGE_05")
syringe.assign_attributes(name: "Seringa 0,5 ml", unit: "unit", active: true)
syringe.save!

lot = ImmunobiologicLot.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  immunobiologic_product: influenza,
  lot_number: "DEMO-2026-01"
)
lot.assign_attributes(expires_on: 1.year.from_now.to_date, manufacturer: "Demo Lab", quantity_on_hand: 500)
lot.save!

StockBalance.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  immunobiologic_lot: lot
).update!(quantity: lot.quantity_on_hand)

StockBalance.find_or_initialize_by(
  municipality: municipality,
  health_facility: facility_a,
  supply_item: syringe
).update!(quantity: 1_000)

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
  RoomCapacitySlot.find_or_create_by!(
    municipality: municipality,
    health_facility: facility_a,
    consultation_room: vaccination_room,
    slot_date: date,
    starts_at: Time.zone.parse("#{date} 08:00"),
    ends_at: Time.zone.parse("#{date} 17:00")
  ) do |slot|
    slot.capacity = 80
    slot.booked_count = 0
  end
end

puts "  Inventory seed: #{ImmunobiologicProduct.count} products, #{ImmunobiologicLot.count} lots, #{RoomCapacitySlot.count} capacity slots"

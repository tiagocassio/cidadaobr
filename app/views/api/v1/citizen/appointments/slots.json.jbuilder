json.array! @slots do |slot|
  json.id slot.id
  json.consultation_room_id slot.consultation_room_id
  json.room_name slot.consultation_room.name
  json.starts_at slot.starts_at.strftime("%H:%M")
  json.ends_at slot.ends_at.strftime("%H:%M")
  json.remaining_capacity slot.capacity - slot.booked_count
end

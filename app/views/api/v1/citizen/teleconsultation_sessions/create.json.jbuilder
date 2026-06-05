json.session do
  json.id @session.id
  json.status @session.status
  json.scheduled_at @session.scheduled_at&.iso8601
  json.room_token @session.room_token
end

json.panic_alert do
  json.id @panic_alert.id
  json.status @panic_alert.status
  json.triggered_at @panic_alert.triggered_at.iso8601
end

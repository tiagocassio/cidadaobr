json.id @appointment.id
json.scheduled_at @appointment.scheduled_at.iso8601
json.status @appointment.status
json.service @appointment.appointment_service_type.name

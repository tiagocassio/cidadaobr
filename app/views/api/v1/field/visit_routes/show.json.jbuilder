json.id @route.id
json.route_date @route.route_date
json.sequence_number @route.sequence_number
json.status @route.status
json.care_team_id @route.care_team_id

json.stops @route.visit_route_stops.order(:stop_order) do |stop|
  json.stop_order stop.stop_order
  json.citizen_id stop.citizen_id
  json.citizen_name stop.citizen.full_name
  json.household_id stop.household_id
  json.status stop.status
end

if @provisioning
  json.provisioning do
    json.status @provisioning.status
    json.lines @provisioning.lines_json
  end
end

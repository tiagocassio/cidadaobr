json.array! @routes do |route|
  json.id route.id
  json.route_date route.route_date
  json.sequence_number route.sequence_number
  json.status route.status
  json.care_team_id route.care_team_id
  json.stop_count route.visit_route_stops.size
end

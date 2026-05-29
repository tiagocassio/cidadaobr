json.array! @campaigns do |campaign|
  json.id campaign.id
  json.name campaign.name
  json.status campaign.status
  json.starts_on campaign.starts_on
  json.ends_on campaign.ends_on
  json.health_facility_id campaign.health_facility_id
end

json.token @token
json.scope @membership.scope
json.municipality_id @membership.municipality_id
json.health_facility_id @membership.health_facility_id if @membership.health_facility_id.present?

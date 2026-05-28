json.applied_records_percent @applied_records_percent
json.records @records do |record|
  json.vaccine_code record.vaccine_code
  json.vaccine_name record.vaccine_name
  json.dose_label record.dose_label
  json.applied_on record.applied_on
  json.lot_number record.lot_number
end

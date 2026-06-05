json.array! @medications do |medication|
  json.id medication.id
  json.medication_name medication.medication_name
  json.dosage medication.dosage
  json.frequency medication.frequency
  json.started_on medication.started_on
  json.active medication.active
end

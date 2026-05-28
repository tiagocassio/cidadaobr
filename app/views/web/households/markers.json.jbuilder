json.array! @markers do |marker|
  json.id marker[:id]
  json.lat marker[:lat]
  json.lng marker[:lng]
  json.label marker[:label]
  json.url marker[:url]
end

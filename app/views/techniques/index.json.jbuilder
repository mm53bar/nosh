json.array! @techniques do |technique|
  json.id technique.id
  json.title technique.title
  json.equipment technique.equipment.map(&:name)
end

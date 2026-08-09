json.array! @items do |item|
  json.id item.id
  json.name item.name
  json.amount item.amount
  json.unit item.unit
  json.category item.category
  json.checked item.checked
end

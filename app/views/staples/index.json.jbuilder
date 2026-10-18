json.array! @aisles do |aisle|
  json.aisle aisle.name
  json.staples aisle.staples do |staple|
    json.extract! staple, :id, :name, :needed, :group_name, :aliases, :note
  end
end

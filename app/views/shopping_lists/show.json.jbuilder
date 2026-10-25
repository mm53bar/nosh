json.speech ShoppingBoard.new.read_back

json.board @aisles do |aisle|
  json.aisle aisle.name
  json.staples aisle.staples do |staple|
    json.extract! staple, :id, :name, :needed, :group_name, :note
    json.markers staple.shopping_list_items do |item|
      json.quantity item.quantity.presence
      json.source item.source
    end
  end
end

json.write_ins @write_ins do |write_in|
  json.extract! write_in, :id, :name
  json.promotable write_in.promotable?
end

json.this_week @items do |item|
  json.extract! item, :id, :name, :unit, :source, :checked
  json.amount item.amount&.to_f
  json.amount_max item.amount_max&.to_f
  json.quantity item.quantity.presence
end

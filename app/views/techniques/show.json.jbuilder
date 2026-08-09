json.id @technique.id
json.title @technique.title
json.body @technique.body
json.equipment @technique.equipment.map(&:name)
json.recipes @technique.recipes.map { |r| { id: r.id, title: r.title } }

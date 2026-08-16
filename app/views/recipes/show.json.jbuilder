json.id @recipe.id
json.title @recipe.title
json.source_url @recipe.source_url
json.description @recipe.description
json.servings @recipe.servings
json.cuisine @recipe.cuisine
json.meal_type @recipe.meal_type
json.prep_time_minutes @recipe.prep_time_minutes
json.total_time_minutes @recipe.total_time_minutes
json.notes @recipe.notes
json.rating @recipe.rating
json.last_made_on @recipe.last_made_on
json.image_url(@recipe.image.attached? ? url_for(@recipe.image) : nil)
json.tags @recipe.tag_names
json.equipment @recipe.equipment_names
json.techniques @recipe.techniques.map { |t| { id: t.id, title: t.title } }
json.ingredients @recipe.ingredients do |ingredient|
  json.id ingredient.id
  json.amount ingredient.amount
  json.unit ingredient.unit
  json.name ingredient.name
  json.note ingredient.note
  json.position ingredient.position
end
json.steps @recipe.steps do |step|
  json.id step.id
  json.instruction step.instruction
  json.position step.position
end

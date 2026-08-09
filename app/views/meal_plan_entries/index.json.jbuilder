json.array! @entries do |entry|
  json.id entry.id
  json.date entry.date
  json.recipe_id entry.recipe_id
  json.recipe_title entry.recipe.title
  json.servings entry.servings
  json.notes entry.notes
end

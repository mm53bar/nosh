json.array! @recipes do |recipe|
  json.id recipe.id
  json.title recipe.title
  json.cuisine recipe.cuisine
  json.meal_type recipe.meal_type
  json.rating recipe.rating
  json.last_made_on recipe.last_made_on
  json.image_url(recipe.image.attached? ? url_for(recipe.image) : nil)
  json.tags recipe.tag_names
end

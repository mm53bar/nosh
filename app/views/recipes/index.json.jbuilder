json.array! @recipes do |recipe|
  json.id recipe.id
  json.title recipe.title
  json.source_url recipe.source_url
  json.cuisine recipe.cuisine
  json.meal_type recipe.meal_type
  json.rating recipe.rating
  # Emitted on the index so a client can bucket by effort without fetching every
  # recipe — the HTML card grid already derives its effort dot from these.
  json.prep_time_minutes recipe.prep_time_minutes
  json.total_time_minutes recipe.total_time_minutes
  json.last_made_on recipe.last_made_on
  json.image_url(recipe.image.attached? ? url_for(recipe.image) : nil)
  json.tags recipe.tag_names
end

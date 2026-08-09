module RecipesHelper
  # schema.org/Recipe as a Hash, embedded as JSON-LD on the recipe page so
  # recipe-import tools (Paprika, browser clippers, etc.) and search engines
  # can read it — schema.org's Recipe type superseded the old hRecipe
  # microformat years ago; this is what those tools actually parse today.
  def recipe_structured_data(recipe)
    {
      "@context" => "https://schema.org/",
      "@type" => "Recipe",
      "name" => recipe.title,
      "url" => recipe_url(recipe),
      "image" => (recipe.image.attached? ? [ url_for(recipe.image) ] : nil),
      "description" => recipe.description,
      "recipeYield" => recipe.servings&.to_s,
      "prepTime" => iso8601_minutes(recipe.prep_time_minutes),
      "totalTime" => iso8601_minutes(recipe.total_time_minutes),
      "recipeCuisine" => recipe.cuisine,
      "recipeCategory" => recipe.meal_type,
      "keywords" => recipe.tag_names.presence&.join(", "),
      "recipeIngredient" => recipe.ingredients.map { |i| [ i.amount, i.unit, i.name ].compact_blank.join(" ") },
      "recipeInstructions" => recipe.steps.map { |s| { "@type" => "HowToStep", "text" => s.instruction } }
    }.compact
  end

  # Effort facet for the recipe-list sidebar — the old app had one, but
  # nothing in the data model tracks it directly, so it's bucketed from
  # total_time_minutes rather than being its own stored field.
  EFFORT_BUCKETS = [ [ 30, "Quick" ], [ 60, "Medium" ] ].freeze

  def recipe_effort(recipe)
    minutes = recipe.total_time_minutes
    return nil if minutes.blank?

    _, label = EFFORT_BUCKETS.find { |max, _| minutes <= max }
    label || "Involved"
  end

  private

  def iso8601_minutes(minutes)
    "PT#{minutes}M" if minutes.present?
  end
end

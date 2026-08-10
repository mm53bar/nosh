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

  # Same colors as the old app's .effort-dot CSS (green/orange/red).
  EFFORT_COLORS = { "Quick" => "#27ae60", "Medium" => "#e67e22", "Involved" => "#c0392b" }.freeze

  def effort_dot(effort_label)
    return nil if effort_label.blank?

    tag.span("", class: "inline-block w-2.5 h-2.5 rounded-full shrink-0",
      style: "background-color: #{EFFORT_COLORS.fetch(effort_label, '#bbb')}")
  end

  # Filled + dimmed-empty stars, matching the old app's stars() helper
  # (e.g. rating 3 → "★★★" in amber, "★★" in a dim gray).
  def recipe_stars(rating)
    return tag.span("Unrated", class: "text-stone-400 text-xs italic") if rating.nil?

    tag.span(class: "text-amber-500 tracking-tight") do
      safe_join([ "★" * rating, tag.span("★" * (5 - rating), class: "text-stone-300") ])
    end
  end

  def rating_filter_label(value)
    return "Unrated" if value == "unrated"
    return "★★★★★ only" if value == "5"

    "#{"★" * value.to_i}+ and up"
  end

  # "25m" / "1h" / "1h 30m" — matches the old app's formatTime() exactly.
  def format_minutes(minutes)
    return nil if minutes.blank?
    return "#{minutes}m" if minutes < 60

    hours, remainder = minutes.divmod(60)
    remainder.positive? ? "#{hours}h #{remainder}m" : "#{hours}h"
  end

  private

  def iso8601_minutes(minutes)
    "PT#{minutes}M" if minutes.present?
  end
end

module ApplicationHelper
  # A named variant, or the original when the blob cannot be transformed at all
  # (Active Storage raises rather than degrading, and an un-analyzed or
  # non-image blob is not hypothetical — recipes are imported from the web).
  # Every view that shows a recipe photo goes through here so the fallback
  # exists in one place instead of being re-derived per call site.
  def recipe_image_source(recipe, variant)
    recipe.image.variable? ? recipe.image.variant(variant) : recipe.image
  end
end

module KitchenHelper
  # Card thumbnails, sized for the wall screen rather than served as originals.
  # The stored photos are full-resolution (up to ~200 KB each), which is a lot
  # of decode for a 1 GB Echo Show; at 480×270 a card is a fraction of that.
  # Variants are generated on first request and cached from then on.
  KITCHEN_CARD_VARIANT = { resize_to_fill: [ 480, 270 ] }.freeze

  def kitchen_card_image(recipe, **options)
    return nil unless recipe.image.attached?

    source = recipe.image.variable? ? recipe.image.variant(**KITCHEN_CARD_VARIANT) : recipe.image
    image_tag source, loading: "lazy", **options
  end

  def last_made_label(recipe)
    return "Never made" if recipe.last_made_on.nil?
    return "Made today" if recipe.last_made_on == Date.current

    "Last made #{time_ago_in_words(recipe.last_made_on)} ago"
  end
end

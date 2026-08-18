module KitchenHelper
  # Card thumbnails, sized for the wall screen rather than served as originals.
  # The stored photos are full-resolution (up to ~200 KB each), which is a lot
  # of decode for a 1 GB Echo Show; at 480×270 a card is a fraction of that.
  # Variants are generated on first request and cached from then on.
  KITCHEN_CARD_VARIANT = { resize_to_fill: [ 480, 270 ] }.freeze

  # The recipe screen's corner thumbnail. Small, but the kiosk renders at dpr
  # 1.5, so the variant is drawn at twice the CSS box.
  KITCHEN_CORNER_VARIANT = { resize_to_fill: [ 224, 176 ] }.freeze

  def kitchen_card_image(recipe, **options)
    return nil unless recipe.image.attached?

    source = recipe.image.variable? ? recipe.image.variant(**KITCHEN_CARD_VARIANT) : recipe.image
    image_tag source, loading: "lazy", **options
  end

  def kitchen_corner_image(recipe, **options)
    return nil unless recipe.image.attached?

    source = recipe.image.variable? ? recipe.image.variant(**KITCHEN_CORNER_VARIANT) : recipe.image
    image_tag source, **options
  end

  def last_made_label(recipe)
    return "Never made" if recipe.last_made_on.nil?
    return "Made today" if recipe.last_made_on == Date.current

    "Last made #{time_ago_in_words(recipe.last_made_on)} ago"
  end

  # `?embed=1` (see Kitchen::BaseController): Home Assistant floats its own back
  # button over the top-left corner of the frame — a 46px circle, inset 14px,
  # wanting 14px of clearance — so nothing of nosh's may need reading or tapping
  # inside that 14+46+14 = 74px square. Leaving it blank is one way to satisfy
  # that; putting a photo under it is the better one, and is what the recipe
  # screen does. This is the blank version, for screens with no image to give.
  # Both axes, even though only the horizontal one bites today: the min-height
  # is what stops a short header from sliding the row below it under the button.
  # Spelled out rather than interpolated from the arithmetic, because Tailwind
  # only compiles an arbitrary value it can read literally in the source.
  EMBED_CORNER_RESERVE = "ps-[74px] min-h-[74px]".freeze

  # Every kitchen screen's topmost element runs its leading padding through
  # this, so the corner is reserved in one place rather than per view.
  def kitchen_corner_reserve(unembedded_padding)
    kitchen_embed? ? EMBED_CORNER_RESERVE : unembedded_padding
  end
end

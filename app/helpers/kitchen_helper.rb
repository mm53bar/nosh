module KitchenHelper
  # Card thumbnails, sized for the wall screen rather than served as originals.
  # The stored photos are full-resolution — median 140 KB but with a long tail
  # (one was 8192×5464 at 14.9 MB until 2026-08-18), which is a lot of decode
  # for a 1 GB Echo Show; at 480×270 a card is a fraction of that.
  #
  # The sizes live on the model as the named :kitchen_card / :kitchen_corner
  # variants now, not as hashes here, so they can be warmed — see Recipe.

  def kitchen_card_image(recipe, **options)
    return nil unless recipe.image.attached?

    image_tag recipe_image_source(recipe, :kitchen_card), loading: "lazy", **options
  end

  # Not lazy, unlike the cards: this one is the first thing on the screen.
  def kitchen_corner_image(recipe, **options)
    return nil unless recipe.image.attached?

    image_tag recipe_image_source(recipe, :kitchen_corner), **options
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

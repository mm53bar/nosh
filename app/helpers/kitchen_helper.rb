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

  # `?embed=1` (see Kitchen::BaseController): Home Assistant floats its own
  # close button over the top-left corner of the frame — a 46px circle, inset
  # 14px, wanting 14px of clearance — so nosh has to leave a 14+46+14 = 74px
  # square there empty. Reserved as the leading padding of whatever sits at the
  # top of the screen, which on both kitchen screens is a header taller than
  # 74px already; a shorter one would need vertical room reserved too. Spelled
  # out rather than interpolated from the arithmetic, because Tailwind only
  # compiles an arbitrary value it can read literally in the source.
  EMBED_CORNER_PADDING = "ps-[74px]".freeze

  # Every kitchen screen's topmost element runs its leading padding through
  # this, so the corner is reserved in one place rather than per view.
  def kitchen_lead_padding(unembedded)
    kitchen_embed? ? EMBED_CORNER_PADDING : unembedded
  end
end

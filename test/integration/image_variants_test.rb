require "test_helper"

# The sizes the views ask for are declared on the model as *named* variants
# rather than passed inline as transformation hashes, because a variant
# identified only by an anonymous hash at a call site is invisible to any
# backfill — nothing can warm what it cannot enumerate. Generating a variant on
# the first request that asks for it means libvips work on one of only three
# Puma threads. See docs/adr/20260818-named-variants-so-they-can-be-warmed.md.
class ImageVariantsTest < ActionDispatch::IntegrationTest
  setup do
    @recipe = recipes(:one)
    @recipe.image.attach(
      io: file_fixture("recipe.jpg").open, filename: "recipe.jpg", content_type: "image/jpeg"
    )
  end

  test "every size the views ask for is declared as a named variant" do
    declared = Recipe.attachment_reflections["image"].named_variants.keys

    assert_equal %i[ card kitchen_card kitchen_corner ].sort, declared.sort,
      "rake images:warm can only backfill variants it can enumerate"
  end

  test "named variants are preprocessed, so attaching generates them" do
    named = Recipe.attachment_reflections["image"].named_variants

    named.each do |name, variant|
      assert variant.preprocessed?(@recipe), "#{name} must be preprocessed, or first request pays for it"
    end
  end

  # A cold /recipes was ~18 MB across 127 immediate requests for full-size
  # originals, into CSS boxes about 360px wide.
  test "the browser index serves a sized variant, deferred until scroll" do
    get recipes_path

    assert_response :success
    assert_select "img[loading=lazy]", minimum: 1
    assert_select "img[src*=?]", "/rails/active_storage/representations/", minimum: 1
    assert_select "img[src*=?]", "/rails/active_storage/blobs/", count: 0
  end

  # KitchenHelper had this fallback before the variants were named and it is easy
  # to lose in a refactor: Active Storage raises rather than degrading when a
  # blob cannot be transformed, and recipes are imported from arbitrary pages.
  test "an untransformable blob falls back to the original" do
    @recipe.image.attach(
      io: StringIO.new("%PDF-1.4 not an image"), filename: "card.pdf", content_type: "application/pdf"
    )

    get recipes_path

    assert_response :success
    assert_select "img[src*=?]", "/rails/active_storage/blobs/", minimum: 1
  end
end

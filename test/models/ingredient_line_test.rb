require "test_helper"

class IngredientLineTest < ActiveSupport::TestCase
  test "splits a plain quantity, unit and name" do
    parsed = IngredientLine.parse("200 g tofu")

    assert_equal "200", parsed.amount
    assert_equal "g", parsed.unit
    assert_equal "tofu", parsed.name
    assert_nil parsed.note
  end

  test "reads a mixed number as one amount" do
    assert_equal "1 1/2", IngredientLine.parse("1 1/2 cups all-purpose flour").amount
    assert_equal "1 ½", IngredientLine.parse("1 ½ cups flour").amount
  end

  test "moves a package size out of the name" do
    parsed = IngredientLine.parse("1 (14 ounce) package extra-firm tofu")

    assert_equal "1", parsed.amount
    assert_equal "package", parsed.unit
    assert_equal "extra-firm tofu", parsed.name
    assert_equal "14 ounce", parsed.note
  end

  test "moves a trailing preparation clause to the note" do
    parsed = IngredientLine.parse("1 (10 oz) package fresh butternut squash, cut into cubes")

    assert_equal "fresh butternut squash", parsed.name
    assert_equal "10 oz; cut into cubes", parsed.note
  end

  # The comma here separates two adjectives, not a prep instruction. Splitting
  # on it would leave the shopping list saying "extra-firm" with no noun.
  test "leaves a comma alone when what follows is not a preparation" do
    parsed = IngredientLine.parse("1 (14 ounce) packages extra-firm, water-packed tofu")

    assert_equal "extra-firm, water-packed tofu", parsed.name
    assert_equal "14 ounce", parsed.note
  end

  # "28-ounce" is a size, not a second quantity — an earlier version read this
  # as amount "3 28" and left the name starting with "ounce".
  test "does not absorb a hyphenated size into the amount" do
    parsed = IngredientLine.parse("3 28-ounce cans of San Marzano tomatoes")

    assert_equal "3", parsed.amount
    assert_equal "28-ounce cans of San Marzano tomatoes", parsed.name
  end

  test "does not read a leading hyphenated size as an amount" do
    parsed = IngredientLine.parse("28-ounce can crushed tomatoes")

    assert_nil parsed.amount
    assert_equal "28-ounce can crushed tomatoes", parsed.name
  end

  # Real data: "2–3 heads baby bok choy". Reading only the "2" left the name
  # starting with the leftover "3".
  test "keeps a quantity range together" do
    parsed = IngredientLine.parse("2–3 heads baby bok choy, halved lengthwise")

    assert_equal "2–3", parsed.amount
    assert_equal "heads", parsed.unit
    assert_equal "baby bok choy", parsed.name
    assert_equal "halved lengthwise", parsed.note
  end

  # Real data: "Jalapeno ((seeds removed and coarsely chopped))". A single pass
  # left a stray bracket welded to the name.
  test "unwraps doubled brackets without leaving a stray one" do
    parsed = IngredientLine.parse("Jalapeno ((seeds removed and coarsely chopped))")

    assert_equal "Jalapeno", parsed.name
    assert_equal "seeds removed and coarsely chopped", parsed.note
  end

  test "handles a quantity run together with its unit" do
    parsed = IngredientLine.parse("100ml white wine")

    assert_equal "100", parsed.amount
    assert_equal "ml", parsed.unit
    assert_equal "white wine", parsed.name
  end

  # Substitutions are a judgment call — trimming to "white wine" would silently
  # delete a real option. IngredientNameLinter flags these for a human instead.
  test "keeps substitution options in the name" do
    parsed = IngredientLine.parse("100ml white wine or vermouth (optional)")

    assert_equal "white wine or vermouth", parsed.name
    assert_equal "optional", parsed.note
  end

  # The one live instance of this in the collection is an allergen warning, so
  # losing it is worse than an untidy note.
  test "preserves a trailing warning in the note" do
    parsed = IngredientLine.parse("2 tbsp chili crisp, plus more for serving (optional) — check label for shrimp")

    assert_equal "chili crisp", parsed.name
    assert_includes parsed.note, "check label for shrimp"
  end

  test "keeps a line whole when the split would leave nothing useful" do
    parsed = IngredientLine.parse("Salt and pepper to taste")

    assert_nil parsed.amount
    assert_equal "Salt and pepper to taste", parsed.name
  end

  test "handles a blank line" do
    parsed = IngredientLine.parse("")

    assert_equal "", parsed.name
    assert_nil parsed.note
  end

  test "keeps a percentage as part of the name" do
    parsed = IngredientLine.parse("100% powdered cacao")

    assert_nil parsed.amount
    assert_equal "100% powdered cacao", parsed.name
  end

  test "reads a multiplier as a count and its size as a note" do
    parsed = IngredientLine.parse("2x 400g cans cannellini beans")

    assert_equal "2", parsed.amount
    assert_equal "cans", parsed.unit
    assert_equal "cannellini beans", parsed.name
    assert_equal "400g", parsed.note
  end

  test "strips a leading list marker before parsing" do
    parsed = IngredientLine.parse("- 2 teaspoons Asian chili sauce")

    assert_equal "2", parsed.amount
    assert_equal "Asian chili sauce", parsed.name
  end

  # "Pinch" is a unit, which would otherwise leave the name as "of ground pepper".
  test "drops a dangling of left by the unit" do
    assert_equal "ground pepper", IngredientLine.parse("Pinch of ground pepper").name
  end

  test "strips a footnote asterisk from the name" do
    assert_equal "extra-firm tofu", IngredientLine.parse("extra-firm tofu*, drained").name
  end

  test "drops a note that is only a price" do
    assert_nil IngredientLine.parse("plain breadcrumbs ($0.26)").note
  end

  test "converts to ingredient attributes" do
    assert_equal({ amount: "200", unit: "g", name: "tofu", note: nil }, IngredientLine.parse("200 g tofu").to_attributes)
  end
end

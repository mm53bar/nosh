require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "splits a freeform name into name and note on create" do
    ingredient = recipes(:one).ingredients.create!(name: "1 (14 ounce) package extra-firm tofu, drained")

    assert_equal "extra-firm tofu", ingredient.name
    assert_equal "14 ounce; drained", ingredient.note
    assert_equal 1, ingredient.amount
    assert_equal "package", ingredient.unit
  end

  # A caller that already split it is trusted; re-parsing would fight them.
  test "leaves a name alone when the caller supplied a note" do
    ingredient = recipes(:one).ingredients.create!(name: "extra-firm tofu, drained", note: "mine")

    assert_equal "extra-firm tofu, drained", ingredient.name
    assert_equal "mine", ingredient.note
  end

  test "never discards an amount or unit the caller sent" do
    ingredient = recipes(:one).ingredients.create!(name: "400g dried spaghetti", amount: "2", unit: "boxes")

    assert_equal 2, ingredient.amount
    assert_equal "boxes", ingredient.unit
    assert_equal "dried spaghetti", ingredient.name
  end

  # An update is a person deciding. Re-parsing there would undo the backfill.
  test "does not re-split on update" do
    ingredient = recipes(:one).ingredients.create!(name: "tofu")
    ingredient.update!(name: "1 (14 ounce) package extra-firm tofu, drained")

    assert_equal "1 (14 ounce) package extra-firm tofu, drained", ingredient.name
    assert_nil ingredient.note
  end

  test "stores a written amount as a number and shows it with a glyph" do
    ingredient = recipes(:one).ingredients.create!(name: "flour", amount: "1 and 1/2", unit: "cups")

    assert_equal BigDecimal("1.5"), ingredient.reload.amount
    assert_nil ingredient.amount_max
    assert_equal "1½ cups", ingredient.quantity
  end

  test "stores a range as a low and a high amount" do
    ingredient = recipes(:one).ingredients.create!(name: "garlic", amount: "2-3", unit: "cloves")

    assert_equal [ 2, 3 ], [ ingredient.amount, ingredient.amount_max ]
    assert_equal "2–3 cloves", ingredient.quantity
  end

  test "a single amount replaces an earlier range" do
    ingredient = recipes(:one).ingredients.create!(name: "garlic", amount: "2-3")
    ingredient.update!(amount: "4")

    assert_nil ingredient.reload.amount_max
  end

  test "moves an amount with no number in it to the front of the note" do
    ingredient = recipes(:one).ingredients.create!(name: "salt", amount: "to taste", note: "flaky")

    assert_nil ingredient.amount
    assert_equal "to taste; flaky", ingredient.note
  end

  test "leaves an already-clean name untouched" do
    ingredient = recipes(:one).ingredients.create!(name: "tahini", amount: "200", unit: "g")

    assert_equal "tahini", ingredient.name
    assert_nil ingredient.note
  end

  test "keeps the line it was created from" do
    ingredient = recipes(:one).ingredients.create!(name: "1 (14 ounce) package extra-firm tofu, drained")

    assert_equal "1 (14 ounce) package extra-firm tofu, drained", ingredient.original_text
  end

  test "builds the original line from fields a caller sent already split" do
    ingredient = recipes(:one).ingredients.create!(amount: "1 1/2", unit: "cups", name: "rice", note: "rinsed")

    assert_equal "1 1/2 cups rice, rinsed", ingredient.original_text
  end

  test "never overwrites the original line on update" do
    ingredient = recipes(:one).ingredients.create!(name: "2 cups rice", original_text: "2 cups rice (any kind)")
    ingredient.update!(name: "jasmine rice", original_text: "something else")

    assert_equal "2 cups rice (any kind)", ingredient.reload.original_text
  end

  test "applies an alias to a new ingredient, after splitting the line" do
    IngredientAlias.create!(variant: "Scallions", canonical: "green onions")

    ingredient = recipes(:one).ingredients.create!(name: "3 scallions, thinly sliced")

    assert_equal "green onions", ingredient.name
    assert_equal "thinly sliced", ingredient.note
    assert_equal "3 scallions, thinly sliced", ingredient.original_text
  end

  test "an alias does not rename on update, which is someone deciding" do
    ingredient = recipes(:one).ingredients.create!(name: "tofu")
    IngredientAlias.create!(variant: "scallions", canonical: "green onions")
    ingredient.update!(name: "scallions")

    assert_equal "scallions", ingredient.name
  end

  test "scales a quantity by a servings ratio" do
    ingredient = recipes(:one).ingredients.create!(amount: "1/3", unit: "cup", name: "rice", note: "x")

    assert_equal "1 cup", ingredient.quantity(3)
    assert_equal "½ cup", ingredient.quantity(Rational(3, 2))
  end
end

require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "splits a freeform name into name and note on create" do
    ingredient = recipes(:one).ingredients.create!(name: "1 (14 ounce) package extra-firm tofu, drained")

    assert_equal "extra-firm tofu", ingredient.name
    assert_equal "14 ounce; drained", ingredient.note
    assert_equal "1", ingredient.amount
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

    assert_equal "2", ingredient.amount
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

  test "leaves an already-clean name untouched" do
    ingredient = recipes(:one).ingredients.create!(name: "tahini", amount: "200", unit: "g")

    assert_equal "tahini", ingredient.name
    assert_nil ingredient.note
  end
end

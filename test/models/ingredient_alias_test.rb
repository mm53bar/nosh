require "test_helper"

class IngredientAliasTest < ActiveSupport::TestCase
  test "renames every ingredient already using the variant, ignoring case" do
    ingredients(:one).update!(name: "TOFU ")
    ingredients(:three).update!(name: "tofu")

    ingredient_alias = IngredientAlias.create!(variant: "Tofu", canonical: "firm tofu")

    assert_equal "tofu", ingredient_alias.variant
    assert_equal 2, ingredient_alias.renamed
    assert_equal [ "firm tofu" ], [ ingredients(:one), ingredients(:three) ].map { |i| i.reload.name }.uniq
    assert_equal "Soy Sauce", ingredients(:two).reload.name
  end

  test "a variant naming itself settles its casing" do
    ingredients(:one).update!(name: "TOFU")

    ingredients(:three).update!(name: "tofu")

    ingredient_alias = IngredientAlias.create!(variant: "Tofu", canonical: "tofu")

    assert_equal 1, ingredient_alias.renamed
    assert_equal "tofu", ingredients(:one).reload.name
    assert_equal "tofu", recipes(:one).ingredients.create!(name: "Tofu", note: "x").name
  end

  test "a canonical that is itself a variant resolves to its canonical" do
    IngredientAlias.create!(variant: "spring onions", canonical: "green onions")

    assert_equal "green onions", IngredientAlias.create!(variant: "scallions", canonical: "spring onions").canonical
  end

  test "aliases pointing at a new variant follow it, so there are no chains" do
    IngredientAlias.create!(variant: "scallions", canonical: "spring onions")
    IngredientAlias.create!(variant: "spring onions", canonical: "green onions")

    assert_equal "green onions", IngredientAlias.canonical_for("Scallions")
  end

  test "an alias that would undo another is refused" do
    IngredientAlias.create!(variant: "scallions", canonical: "green onions")

    assert_not IngredientAlias.new(variant: "green onions", canonical: "scallions").valid?
  end
end

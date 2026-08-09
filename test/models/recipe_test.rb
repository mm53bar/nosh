require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "requires a title" do
    recipe = Recipe.new
    assert_not recipe.valid?
    assert_includes recipe.errors[:title], "can't be blank"
  end

  test "rating must be within 1..5 when present" do
    recipe = recipes(:one)
    recipe.rating = 6
    assert_not recipe.valid?
    recipe.rating = nil
    assert recipe.valid?
  end

  test "tag_names= resolves existing tags and creates new ones" do
    recipe = recipes(:one)
    recipe.tag_names = [ "vegetarian", "new-tag" ]
    assert_equal [ "new-tag", "vegetarian" ], recipe.tag_names.sort
    assert Tag.exists?(name: "new-tag")
  end

  test "equipment_names= resolves existing equipment and creates new ones" do
    recipe = recipes(:one)
    recipe.equipment_names = [ "Instant Pot", "Stand mixer" ]
    assert_equal [ "Instant Pot", "Stand mixer" ], recipe.equipment_names.sort
    assert Equipment.exists?(name: "Stand mixer")
  end

  test "planned_since finds recipes with a meal-plan entry on or after the date" do
    assert_includes Recipe.planned_since(Date.new(2026, 8, 1)), recipes(:one)
    assert_not_includes Recipe.planned_since(Date.new(2026, 8, 12)), recipes(:one)
  end

  test "destroying a recipe destroys its ingredients, steps, and meal-plan entries" do
    recipe = recipes(:one)
    ingredient_ids = recipe.ingredients.pluck(:id)
    recipe.destroy!
    assert_empty Ingredient.where(id: ingredient_ids)
    assert_empty MealPlanEntry.where(recipe_id: recipe.id)
  end
end

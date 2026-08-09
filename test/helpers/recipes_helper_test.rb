require "test_helper"

class RecipesHelperTest < ActionView::TestCase
  test "maps a recipe onto schema.org/Recipe" do
    data = recipe_structured_data(recipes(:one))

    assert_equal "Recipe", data["@type"]
    assert_equal "Tofu Noodle Stir-Fry", data["name"]
    assert_equal "PT15M", data["prepTime"]
    assert_equal "PT30M", data["totalTime"]
    assert_equal [ "200 g Tofu", "1 tbsp Soy Sauce" ], data["recipeIngredient"]
    assert_equal [ { "@type" => "HowToStep", "text" => "Press and cube the tofu." } ], data["recipeInstructions"]
  end

  test "omits blank optional fields rather than emitting empty strings" do
    recipe = recipes(:one)
    recipe.update!(description: nil, prep_time_minutes: nil)

    data = recipe_structured_data(recipe)

    assert_not data.key?("description")
    assert_not data.key?("prepTime")
  end
end

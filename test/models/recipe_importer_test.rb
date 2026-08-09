require "test_helper"

class RecipeImporterTest < ActiveSupport::TestCase
  test "builds a recipe from a page's schema.org/Recipe JSON-LD" do
    html = <<~HTML
      <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org/",
          "@type": "Recipe",
          "name": "Test Tofu Stir-Fry",
          "description": "A quick weeknight dinner.",
          "recipeYield": "4 servings",
          "prepTime": "PT15M",
          "totalTime": "PT30M",
          "recipeCuisine": "Asian",
          "recipeCategory": "Dinner",
          "keywords": "vegetarian, quick",
          "recipeIngredient": ["200 g tofu", "1 tbsp soy sauce", "salt to taste"],
          "recipeInstructions": [
            { "@type": "HowToStep", "text": "Press and cube the tofu." },
            { "@type": "HowToStep", "text": "Stir-fry until golden." }
          ]
        }
        </script>
      </head><body></body></html>
    HTML

    result = RecipeImporter.new("https://example.com/tofu-stir-fry", html: html).call

    assert result.success?, result.error
    recipe = result.recipe
    assert_equal "Test Tofu Stir-Fry", recipe.title
    assert_equal "https://example.com/tofu-stir-fry", recipe.source_url
    assert_equal 4, recipe.servings
    assert_equal 15, recipe.prep_time_minutes
    assert_equal 30, recipe.total_time_minutes
    assert_equal "Asian", recipe.cuisine
    assert_equal "Dinner", recipe.meal_type
    assert_equal [ "quick", "vegetarian" ], recipe.tag_names.sort

    assert_equal 3, recipe.ingredients.size
    assert_equal({ amount: "200", unit: "g", name: "tofu" }, recipe.ingredients[0].slice(:amount, :unit, :name).symbolize_keys)
    assert_equal "salt to taste", recipe.ingredients[2].name

    assert_equal [ "Press and cube the tofu.", "Stir-fry until golden." ], recipe.steps.map(&:instruction)
  end

  test "reports an error when the page has no Recipe JSON-LD" do
    result = RecipeImporter.new("https://example.com/not-a-recipe", html: "<html><body>nothing here</body></html>").call

    assert_not result.success?
    assert_match(/no recipe data/i, result.error)
  end

  test "rejects a non-http(s) URL before ever fetching anything" do
    result = RecipeImporter.new("javascript:alert(1)").call

    assert_not result.success?
    assert_match(/invalid url/i, result.error)
  end

  test "finds a Recipe node inside an @graph array" do
    html = <<~HTML
      <script type="application/ld+json">
      { "@context": "https://schema.org/", "@graph": [
        { "@type": "WebSite", "name": "Some Blog" },
        { "@type": ["Recipe"], "name": "Graph Recipe", "recipeIngredient": [], "recipeInstructions": [] }
      ]}
      </script>
    HTML

    result = RecipeImporter.new("https://example.com/graph-recipe", html: html).call

    assert result.success?, result.error
    assert_equal "Graph Recipe", result.recipe.title
  end
end

require "test_helper"

class RecipeSourceTest < ActiveSupport::TestCase
  def page(lines)
    data = { "@context" => "https://schema.org/", "@type" => "Recipe", "name" => "Tofu", "recipeIngredient" => lines }
    %(<html><script type="application/ld+json">{"@graph": [#{data.to_json}]}</script></html>)
  end

  test "keeps the whole page gzipped and the recipe node it found" do
    html = page([ "200 g tofu" ])

    result = RecipeSource.new(recipes(:one)).capture!(html)

    assert result.found
    assert_equal "Tofu", recipes(:one).reload.source_data["name"]
    assert_equal html, RecipeSource.new(recipes(:one)).page
    assert recipes(:one).source_fetched_at
  end

  test "fills each ingredient's original line from the source, in order" do
    RecipeSource.new(recipes(:one)).capture!(page([ "200 g extra-firm Tofu, pressed", "1 tbsp soy sauce" ]))

    assert_equal "200 g extra-firm Tofu, pressed", ingredients(:one).reload.original_text
    assert_equal "1 tbsp soy sauce", ingredients(:two).reload.original_text
  end

  test "pairs a line that only aliases to the ingredient's name" do
    ingredients(:two).update!(name: "green onions")
    IngredientAlias.create!(variant: "scallions", canonical: "green onions")

    RecipeSource.new(recipes(:one)).capture!(page([ "200 g tofu", "2 scallions, sliced" ]))

    assert_equal "2 scallions, sliced", ingredients(:two).reload.original_text
  end

  test "leaves an ingredient blank rather than guessing, and never overwrites one" do
    ingredients(:one).update_column(:original_text, "kept")

    result = RecipeSource.new(recipes(:one)).capture!(page([ "1 cup rice" ]))

    assert_equal 0, result.matched
    assert_equal "kept", ingredients(:one).reload.original_text
    assert_nil ingredients(:two).reload.original_text
  end

  test "a page with no recipe in it is still kept" do
    result = RecipeSource.new(recipes(:one)).capture!("<html>video</html>")

    assert_not result.found
    assert recipes(:one).reload.source_page.attached?
  end

  test "takes ingredient lines from the caller when the page's JSON-LD has none" do
    RecipeSource.new(recipes(:one)).capture!(page([]), lines: [ "200 g Tofu" ])

    assert_equal "200 g Tofu", ingredients(:one).reload.original_text
    assert_equal "page text", recipes(:one).source_data["nosh:ingredientLinesFrom"]
  end

  test "prefers the page's own lines over the caller's" do
    RecipeSource.new(recipes(:one)).capture!(page([ "200 g tofu, cubed" ]), lines: [ "200 g Tofu" ])

    assert_equal "200 g tofu, cubed", ingredients(:one).reload.original_text
  end

  test "pairs a shorter source name once the exact matches have taken their lines" do
    ingredients(:two).update!(name: "fresh basil")

    RecipeSource.new(recipes(:one)).capture!(page([ "200 g tofu", "4 Tbsp Basil" ]))

    assert_equal "200 g tofu", ingredients(:one).reload.original_text
    assert_equal "4 Tbsp Basil", ingredients(:two).reload.original_text
  end
end

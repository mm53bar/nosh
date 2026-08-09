require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "index renders with sidebar facet options computed from the loaded recipes" do
    get recipes_path
    assert_response :success
    assert_select "a[data-facet='cuisine'][data-value=?]", recipes(:one).cuisine
  end

  test "cuisine facet excludes blank strings, not just nil" do
    recipes(:two).update!(cuisine: "")

    get recipes_path
    assert_select "a[data-facet='cuisine'][data-value='']", count: 1 # only the "All" link
  end

  test "index.json still supports query-param filtering for API consumers" do
    get recipes_path(cuisine: recipes(:one).cuisine), as: :json
    body = JSON.parse(response.body)

    assert(body.all? { |r| r["cuisine"] == recipes(:one).cuisine })
  end

  test "import redirects with an error for an invalid URL, with no network access needed" do
    post import_recipes_path, params: { url: "javascript:alert(1)" }

    assert_redirected_to recipes_path
    assert_equal "Invalid URL — must be http:// or https://", flash[:alert]
  end

  test "index.rss renders a valid feed with the recipes' titles and links" do
    get recipes_path(format: :rss)

    assert_response :success
    assert_equal "application/rss+xml", response.media_type
    assert_includes response.body, recipes(:one).title
    assert_includes response.body, recipe_url(recipes(:one))
  end

  test "update accepts equipment_names_text and technique_ids" do
    recipe = recipes(:one)
    patch recipe_path(recipe), params: {
      recipe: { equipment_names_text: "Instant Pot, Stand mixer", technique_ids: [ techniques(:basic_vinaigrette).id ] }
    }

    recipe.reload
    assert_equal [ "Instant Pot", "Stand mixer" ], recipe.equipment_names.sort
    assert_equal [ techniques(:basic_vinaigrette) ], recipe.techniques
  end

  test "index sidebar includes an Equipment facet" do
    recipes(:one).equipment_names = [ "Instant Pot" ]

    get recipes_path
    assert_select "a[data-facet='equipment'][data-value='Instant Pot']"
  end
end

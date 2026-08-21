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

  # The exact shape the one-time note backfill PATCHes with: update ingredients
  # in place by id, setting name and note together. Nested attributes update
  # rather than replace, so an untouched ingredient must survive unchanged.
  test "updates ingredient name and note in place by id" do
    recipe = recipes(:one)
    target = recipe.ingredients.order(:position).first
    untouched = recipe.ingredients.order(:position).last

    patch recipe_path(recipe), params: {
      recipe: { ingredients_attributes: [ { id: target.id, name: "extra-firm tofu", note: "14 ounce; drained" } ] }
    }, as: :json

    assert_response :success
    assert_equal "extra-firm tofu", target.reload.name
    assert_equal "14 ounce; drained", target.note
    assert_equal untouched.name, untouched.reload.name
    assert_equal recipe.ingredients.count, recipe.reload.ingredients.count
  end

  test "the index json carries the fields a slate builder needs" do
    get recipes_path(format: :json)

    row = JSON.parse(response.body).first
    assert row.key?("source_url")
    assert row.key?("prep_time_minutes")
    assert row.key?("total_time_minutes")
  end

  # The JSON branch exists so a caller can hand nosh a URL instead of building
  # a payload. The happy path needs the network, so RecipeImporter's own tests
  # cover the parse; this pins the response shape and status.
  test "importing reports failure as json rather than a redirect" do
    post import_recipes_path(format: :json), params: { url: "javascript:alert(1)" }

    assert_response :unprocessable_entity
    assert_match(/invalid url/i, JSON.parse(response.body)["errors"].first)
  end

  # The iPad's half of the same switch. Its backend differs (a Screen Wake Lock,
  # where the kiosk gets a lease from the host page) but the markup contract the
  # one controller reads is identical.
  test "the show page's method row carries the keep-awake switch" do
    get recipe_path(recipes(:one))

    assert_select "[data-controller=wake-lock]", text: /Keep awake/ do
      assert_select "input[data-wake-lock-target=toggle][data-action=?]", "change->wake-lock#toggle"
    end
  end

  # Revealed by the controller once a backend answers, so a bundle that never
  # loads leaves no switch rather than one that does nothing.
  test "the keep-awake switch is hidden until JS reveals it" do
    get recipe_path(recipes(:one))

    assert_select "[data-controller=wake-lock][hidden]"
  end
end

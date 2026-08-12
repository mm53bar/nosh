require "test_helper"

class Kitchen::MealsControllerTest < ActionDispatch::IntegrationTest
  # The whole point of this screen is being embedded in a Home Assistant
  # dashboard — see docs/adr/20260812-framed-by-home-assistant.md.
  test "the kitchen screen is framable" do
    get kitchen_root_path

    assert_nil response.headers["X-Frame-Options"]
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors"
  end

  test "renders this week's meal plan entries when the week is planned" do
    MealPlanEntry.update_all(date: Date.current)

    get kitchen_root_path

    assert_response :success
    assert_select "h1", "This week"
    assert_select "a[href=?]", kitchen_recipe_path(recipes(:one))
  end

  test "falls back to labelled suggestions when nothing is planned" do
    MealPlanEntry.delete_all

    get kitchen_root_path

    assert_response :success
    assert_select "h1", "Nothing planned"
    assert_select "p", text: /Suggestions/
    assert_select "a[href=?]", kitchen_recipe_path(recipes(:two))
  end

  test "entries outside the current week don't count as a plan" do
    MealPlanEntry.update_all(date: Date.current + 3.weeks)

    get kitchen_root_path

    assert_select "h1", "Nothing planned"
  end

  # The kiosk reloads on its own schedule; the screen must not reshuffle
  # underneath whoever is deciding what to cook.
  test "the fallback selection is stable across consecutive requests" do
    MealPlanEntry.delete_all

    get kitchen_root_path
    first = css_select("h2").map(&:text)
    get kitchen_root_path
    second = css_select("h2").map(&:text)

    assert_equal first, second
    assert_predicate first, :any?
  end

  test "suggestions put rated dinners first, then never-made ones" do
    MealPlanEntry.delete_all
    never_made = Recipe.create!(title: "Never Made Dinner", meal_type: "Dinner")

    get kitchen_root_path
    titles = css_select("h2").map(&:text)

    # recipes(:two) is rated 5, recipes(:one) is rated 4, both have been made.
    assert_equal [ recipes(:two).title, recipes(:one).title, never_made.title ], titles
  end

  test "suggestions exclude non-dinners" do
    MealPlanEntry.delete_all
    Recipe.create!(title: "Morning Toast", meal_type: "Breakfast")

    get kitchen_root_path

    assert_no_match(/Morning Toast/, response.body)
  end
end

require "test_helper"

class ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  test "building from the meal plan replaces this week's lines" do
    entry = meal_plan_entries(:one)
    post generate_shopping_list_path, params: { start_date: entry.date.to_s, end_date: entry.date.to_s }

    assert_redirected_to shopping_list_path
    assert_equal entry.recipe.ingredients.count, ShoppingListItem.count
  end

  test "the list is never pushed anywhere" do
    post "/shopping_list/publish"

    assert_response :not_found
  end

  # nanoclaw once failed silently this way: a JSON body posted to a suffix-less
  # path was treated as an HTML form and answered with a 422 CSRF error page.
  test "a json body is accepted without the .json suffix" do
    ActionController::Base.allow_forgery_protection = true

    post "/shopping_list/generate", params: { start_date: "2026-08-17", end_date: "2026-08-23" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_response :redirect
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end

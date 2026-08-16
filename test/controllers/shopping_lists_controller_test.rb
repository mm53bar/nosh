require "test_helper"

class ShoppingListsControllerTest < ActionDispatch::IntegrationTest
  test "publishing enqueues the push" do
    assert_enqueued_with(job: ShoppingListPushJob) do
      post publish_shopping_list_path
    end

    assert_redirected_to shopping_list_path
  end

  test "publishing with a date range rebuilds the list first" do
    entry = meal_plan_entries(:one)

    assert_enqueued_with(job: ShoppingListPushJob) do
      post publish_shopping_list_path, params: { start_date: entry.date.to_s, end_date: entry.date.to_s }
    end

    assert_equal entry.recipe.ingredients.count, ShoppingListItem.count
  end

  test "publishing answers 202 to an API caller" do
    post publish_shopping_list_path, as: :json

    assert_response :accepted
  end

  # Casey and the button both need to see what a publish would do before one
  # happens — this must never write to the household's list.
  test "previewing reports without enqueueing anything" do
    assert_no_enqueued_jobs only: ShoppingListPushJob do
      get publish_preview_shopping_list_path, as: :json
    end

    assert_response :success
    assert_not JSON.parse(response.body)["configured"], "no HA configured in test env"
  end

  # nanoclaw's first real publish silently failed this way: a JSON body posted to
  # the suffix-less path was treated as an HTML form and answered with a 422 CSRF
  # error page rather than doing anything.
  test "a json body is accepted without the .json suffix" do
    ActionController::Base.allow_forgery_protection = true

    assert_enqueued_with(job: ShoppingListPushJob) do
      post "/shopping_list/publish", params: { start_date: "2026-08-17", end_date: "2026-08-23" }.to_json,
           headers: { "Content-Type" => "application/json" }
    end

    assert_response :redirect
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end

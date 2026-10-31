require "test_helper"

class MealPlanEntriesControllerTest < ActionDispatch::IntegrationTest
  WEEK = Date.new(2026, 8, 10)

  test "the week's ideas sit above the plan, and come first in each night's dropdown" do
    DinnerSlate.create!(week_start: WEEK, status: :ready,
                        ideas: [ { "recipe_id" => recipes(:two).id, "complexity" => "medium", "why" => "Uses the beans." } ])
    get meal_plan_entries_path(start: WEEK)

    assert_select "section h2", "Ideas for the week"
    assert_select "section", text: /Uses the beans/
    assert_select "optgroup[label=?] option", "This week's ideas", text: "Veggie Chili"
  end

  test "an idea already on the plan says which night" do
    DinnerSlate.create!(week_start: WEEK, status: :ready, ideas: [ { "recipe_id" => recipes(:one).id } ])
    get meal_plan_entries_path(start: WEEK)

    assert_select "section", text: /✓ on Tue/
  end

  test "opening the week marks its ideas seen" do
    slate = DinnerSlate.create!(week_start: WEEK, status: :ready, ideas: [])
    get meal_plan_entries_path(start: WEEK)

    assert slate.reload.seen_at
  end

  test "a night can be planned with just a name" do
    post meal_plan_entries_path, params: { meal_plan_entry: { date: WEEK, title: "Burrito night" }, redirect_start: WEEK, redirect_end: WEEK + 6 }
    get meal_plan_entries_path(start: WEEK)

    assert_select "span", text: "Burrito night"
  end

  test "the JSON names a night without a recipe" do
    MealPlanEntry.create!(date: WEEK, title: "Pizza night")
    get meal_plan_entries_path(format: :json, start: WEEK, end: WEEK + 6)

    assert_includes response.parsed_body.map { |entry| entry["title"] }, "Pizza night"
  end

  test "the banner points at a week with new ideas" do
    travel_to WEEK - 2
    DinnerSlate.create!(week_start: WEEK, status: :ready, ideas: [])
    get recipes_path

    assert_select "a[href=?]", meal_plan_entries_path(start: WEEK), text: "Plan the week"
  end

  test "suggesting with no model configured says it couldn't" do
    post dinner_slates_path(week_start: WEEK)

    assert_redirected_to meal_plan_entries_path(start: WEEK)
    assert_match "Couldn't suggest", flash[:alert]
  end
end

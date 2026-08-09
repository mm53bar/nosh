require "test_helper"

class ShoppingListBuilderTest < ActiveSupport::TestCase
  test "aggregates ingredients across meal-plan entries in the date range" do
    ShoppingListBuilder.generate(start_date: Date.new(2026, 8, 11), end_date: Date.new(2026, 8, 12))

    tofu = ShoppingListItem.find_by(name: "Tofu")
    beans = ShoppingListItem.find_by(name: "Black Beans")
    assert_not_nil tofu
    assert_not_nil beans
  end

  test "scales quantities by servings-override over the recipe's own servings" do
    # fixture :one is planned on 2026-08-11 with servings: 8, recipe (:one) servings: 4 — a 2x scale
    ShoppingListBuilder.generate(start_date: Date.new(2026, 8, 11), end_date: Date.new(2026, 8, 11))

    tofu = ShoppingListItem.find_by(name: "Tofu")
    assert_equal "400.0", tofu.amount
    assert_equal "g", tofu.unit
  end

  test "leaves amount nil when no ingredient in the range has a numeric or any amount" do
    ShoppingListBuilder.generate(start_date: Date.new(2020, 1, 1), end_date: Date.new(2020, 1, 2))
    assert_equal 0, ShoppingListItem.count
  end

  test "replaces the entire list rather than appending" do
    ShoppingListItem.create!(name: "Stale Leftover Item")
    ShoppingListBuilder.generate(start_date: Date.new(2026, 8, 11), end_date: Date.new(2026, 8, 12))
    assert_not ShoppingListItem.exists?(name: "Stale Leftover Item")
  end
end

require "test_helper"

class MealPlanEntryTest < ActiveSupport::TestCase
  test "a night can be just a name" do
    entry = MealPlanEntry.create!(date: Date.current, title: "  Burrito   night ")

    assert_equal "Burrito night", entry.name
  end

  test "needs a recipe or a name" do
    assert_not MealPlanEntry.new(date: Date.current, title: " ").valid?
  end

  test "a night without a recipe adds nothing to the shopping list" do
    MealPlanEntry.create!(date: Date.new(2026, 8, 11), title: "Burrito night")

    assert_nothing_raised { ShoppingListBuilder.generate(start_date: Date.new(2026, 8, 10), end_date: Date.new(2026, 8, 16)) }
  end
end

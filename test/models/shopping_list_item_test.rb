require "test_helper"

class ShoppingListItemTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "a bare count is labelled as a count, a measure as itself" do
    assert_equal "×2", ShoppingListItem.new(name: "garlic", amount: "2", unit: "unit").marker_label
    assert_equal "¼ cup", ShoppingListItem.new(name: "feta", amount: "¼", unit: "cup").marker_label
  end
end

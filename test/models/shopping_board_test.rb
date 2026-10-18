require "test_helper"

class ShoppingBoardTest < ActiveSupport::TestCase
  setup { @board = ShoppingBoard.new }

  test "needing a tab flips it and says so" do
    result = @board.need("milk")

    assert staples(:milk).reload.needed?
    assert_equal "Added milk.", result.speech
  end

  test "needing a tab that's already flipped changes nothing and says so" do
    assert_equal "Butter is already on the list.", @board.need("butter").speech
  end

  test "several at once" do
    assert_equal "Added milk and soy sauce.", @board.need("milk and soy sauce").speech
  end

  test "a group word asks which one and flips nothing" do
    result = @board.need("cheese")

    assert_equal "Which cheese? Parmesan or feta.", result.speech
    assert_not staples(:parmesan).reload.needed?
    assert_not staples(:feta).reload.needed?
  end

  # Voice never adds anything that isn't a tab: a fixed vocabulary is what
  # makes a mishearing audible.
  test "an unknown item is refused, with the closest tab and where to add it" do
    assert_no_difference -> { WriteIn.count } do
      assert_equal "Oatmeal isn't on the board, closest is oat milk. You can add it in nosh.", @board.need("oatmeal").speech
    end
  end

  test "having a tab crosses it off" do
    assert_equal "Crossed off butter.", @board.have("butter").speech
    assert_not staples(:butter).reload.needed?
  end

  test "having a tab that wasn't needed says so" do
    assert_equal "Milk wasn't on the list.", @board.have("milk").speech
  end

  test "reading back covers tabs, write-ins and the week" do
    ShoppingListItem.update_all(checked: false)

    speech = @board.read_back

    assert_match "You need butter.", speech
    assert_match(/Written in: .*Advil/, speech)
    assert_match(/Written in: .*birthday candles/, speech)
    assert_match "This week's meals need", speech
  end

  test "an empty list says so" do
    Staple.update_all(needed: false)
    WriteIn.delete_all
    ShoppingListItem.delete_all

    assert_equal "Nothing's on the list.", @board.read_back
  end
end

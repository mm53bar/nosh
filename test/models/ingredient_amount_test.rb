require "test_helper"

class IngredientAmountTest < ActiveSupport::TestCase
  def parse(text) = IngredientAmount.parse(text)&.to_a

  test "parses every way a mixed number gets written to the same number" do
    [ "1 1/2", "1 and 1/2", "1½", "1 ½", "1.5", "3/2", "1-1/2" ].each do |text|
      assert_equal [ 1.5, nil ], parse(text), text
    end
  end

  test "parses whole numbers, bare fractions and decimals" do
    assert_equal [ 200, nil ], parse("200")
    assert_equal [ 0.25, nil ], parse("¼")
    assert_equal [ 0.125, nil ], parse("1/8")
    assert_equal [ 0.5, nil ], parse(".5")
  end

  test "rounds a repeating fraction to four places" do
    assert_equal BigDecimal("0.3333"), IngredientAmount.parse("1/3").amount
    assert_equal BigDecimal("0.6667"), IngredientAmount.parse("0.66666668653488").amount
  end

  test "parses a range into a low and a high amount" do
    assert_equal [ 2, 3 ], parse("2-3")
    assert_equal [ 2, 3 ], parse("2–3")
    assert_equal [ 0.25, 0.5 ], parse("1/4–1/2")
    assert_equal [ 3.5, 4 ], parse("3 1/2 to 4")
  end

  test "collapses a range whose ends are equal" do
    assert_equal [ 3, nil ], parse("3-3")
  end

  test "returns nil for text that is not an amount" do
    assert_nil parse("to taste")
    assert_nil parse("small handful")
    assert_nil parse("1/0")
    assert_nil parse("")
  end

  test "formats a number with a fraction glyph" do
    assert_equal "1½", IngredientAmount.format(BigDecimal("1.5"))
    assert_equal "½", IngredientAmount.format(BigDecimal("0.5"))
    assert_equal "2¾", IngredientAmount.format(BigDecimal("2.75"))
    assert_equal "⅛", IngredientAmount.format(BigDecimal("0.125"))
    assert_equal "200", IngredientAmount.format(BigDecimal("200"))
  end

  test "snaps a stored third, or a total of stored thirds, to its glyph" do
    assert_equal "⅓", IngredientAmount.format(BigDecimal("0.3333"))
    assert_equal "⅔", IngredientAmount.format(BigDecimal("0.6667"))
    assert_equal "1", IngredientAmount.format(BigDecimal("0.3333") * 3)
    assert_equal "⅛", IngredientAmount.format(BigDecimal("0.13"))
  end

  test "shows a decimal that is not a kitchen measure as a decimal" do
    assert_equal "0.3", IngredientAmount.format(BigDecimal("0.3"))
    assert_equal "1.15", IngredientAmount.format(BigDecimal("1.15"))
    assert_equal "0.06", IngredientAmount.format(BigDecimal("0.06"))
  end

  test "formats a range with an en dash" do
    assert_equal "1½–2", IngredientAmount.format(BigDecimal("1.5"), BigDecimal("2"))
    assert_equal "2", IngredientAmount.format(BigDecimal("2"), BigDecimal("2"))
  end

  test "formats nothing as nil" do
    assert_nil IngredientAmount.format(nil)
  end
end

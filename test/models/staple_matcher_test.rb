require "test_helper"

class StapleMatcherTest < ActiveSupport::TestCase
  setup { @matcher = StapleMatcher.new }

  test "matches a tab regardless of case, articles and plural" do
    assert_equal staples(:milk), @matcher.match("Some Milk").staple
    assert_equal staples(:potatoes), @matcher.match("potato").staple
    assert_equal staples(:olive_oil), @matcher.match("the olive oils").staple
  end

  test "matches an alias" do
    assert_equal staples(:parmesan), @matcher.match("parm").staple
  end

  test "a group word answers with its tabs and never a single staple" do
    match = @matcher.match("cheese")

    assert match.group?
    assert_equal "cheese", match.group
    assert_equal %w[feta parmesan], match.choices.map(&:name).sort
  end

  test "a group's plural is the group too" do
    assert @matcher.match("oils").group?
  end

  # Recipes say "feta cheese" far more often than "feta".
  test "a member followed by its group word is that member" do
    assert_equal staples(:feta), @matcher.match("feta cheese").staple
  end

  test "an unknown item names the closest tab when one is close" do
    match = @matcher.match("oatmeal")

    assert match.unknown?
    assert_equal staples(:oat_milk), match.closest
  end

  test "an unknown item containing a tab's words suggests that tab" do
    assert_equal staples(:milk), @matcher.match("almond milk").closest
  end

  test "an unknown item with nothing close suggests nothing" do
    assert_nil @matcher.match("advil").closest
  end

  test "splits several items, but tries the whole phrase first" do
    matches = @matcher.match_all("butter, milk and advil")

    assert_equal [ :staple, :staple, :unknown ], matches.map(&:kind)
    assert_equal [ staples(:butter), staples(:milk) ], matches.first(2).map(&:staple)
  end

  test "spaces don't matter" do
    assert_equal staples(:olive_oil), @matcher.match("oliveoil").staple
  end

  test "a rhyme is not a suggestion" do
    assert_nil @matcher.match("tomatoes").closest
  end
end

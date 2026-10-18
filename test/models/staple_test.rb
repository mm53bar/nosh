require "test_helper"

class StapleTest < ActiveSupport::TestCase
  test "names and aliases are tidied" do
    staple = Staple.create!(name: "  Coffee  Cream ", aisle: aisles(:dairy), aliases_text: "Cream for coffee, ")

    assert_equal "coffee cream", staple.name
    assert_equal [ "cream for coffee" ], staple.aliases
  end

  test "a word can belong to only one tab" do
    staple = Staple.new(name: "parmigiano", aisle: aisles(:dairy), aliases: [ "parm" ])

    assert_not staple.valid?
    assert_match "already belongs to parmesan", staple.errors.full_messages.to_sentence
  end

  test "a group word can't be a tab" do
    staple = Staple.new(name: "cheese", aisle: aisles(:dairy))

    assert_not staple.valid?
    assert_match "is a group of tabs", staple.errors.full_messages.to_sentence
  end

  test "a new tab goes to the end of its aisle" do
    staple = Staple.create!(name: "yogurt", aisle: aisles(:dairy))

    assert_equal aisles(:dairy).staples.maximum(:position), staple.position
  end

  test "an aisle is created by name when it doesn't exist" do
    staple = Staple.create!(name: "ice cream", aisle_name: "Frozen")

    assert_equal "Frozen", staple.aisle.name
    assert_equal Aisle.maximum(:position), staple.aisle.position
  end
end

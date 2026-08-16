require "test_helper"

class ShoppingListPublisherTest < ActiveSupport::TestCase
  # A to-do list that records what was added, standing in for Home Assistant.
  class FakeTodo
    attr_reader :added

    def initialize(existing: [], configured: true, supports_description: true)
      @existing = existing
      @configured = configured
      @supports_description = supports_description
      @added = []
    end

    def configured? = @configured
    def supports_description? = @supports_description
    def open_items = @existing.map { |summary| HomeAssistantTodo::Item.new(summary: summary, status: "needs_action") }
    def add(summary:, description: nil) = @added << { summary: summary, description: description }
  end

  setup do
    ShoppingListItem.delete_all
    @tahini = ShoppingListItem.create!(name: "tahini", amount: "200", unit: "g", source: "Tofu Noodles")
    @eggs = ShoppingListItem.create!(name: "eggs", amount: "6")
  end

  test "adds items that aren't already on the list" do
    todo = FakeTodo.new(existing: [ "eggs" ])

    result = ShoppingListPublisher.new(todo: todo).publish

    assert_equal [ "tahini" ], result.added
    assert_equal [ "eggs" ], result.skipped
    assert_equal [ "tahini" ], todo.added.map { |item| item[:summary] }
  end

  # add_item does not deduplicate: adding "Olive oil" twice yields two entries.
  test "matches an existing item regardless of case or padding" do
    todo = FakeTodo.new(existing: [ "  TAHINI ", "Eggs" ])

    result = ShoppingListPublisher.new(todo: todo).publish

    assert_empty result.added
    assert_empty todo.added
  end

  test "carries quantity and source recipe in the description" do
    todo = FakeTodo.new

    ShoppingListPublisher.new(todo: todo).publish

    tahini = todo.added.find { |item| item[:summary] == "tahini" }
    assert_equal "200 g · Tofu Noodles", tahini[:description]
  end

  # The card renders descriptions as markdown, and recipe titles come from
  # whatever a source site put in its JSON-LD.
  test "strips markdown out of the description" do
    @tahini.update!(source: "*Weeknight* Tofu Noodles")
    todo = FakeTodo.new

    ShoppingListPublisher.new(todo: todo).publish

    assert_equal "200 g · Weeknight Tofu Noodles", todo.added.find { |i| i[:summary] == "tahini" }[:description]
  end

  test "strips a leading markdown block marker from the description" do
    @eggs.update!(amount: nil, source: "# Breakfast Hash")
    todo = FakeTodo.new

    ShoppingListPublisher.new(todo: todo).publish

    assert_equal "Breakfast Hash", todo.added.find { |i| i[:summary] == "eggs" }[:description]
  end

  test "folds the quantity into the name when descriptions are unsupported" do
    todo = FakeTodo.new(supports_description: false)

    ShoppingListPublisher.new(todo: todo).publish

    assert_includes todo.added.map { |item| item[:summary] }, "tahini (200 g)"
  end


  test "leaves checked-off items alone" do
    @eggs.update!(checked: true)
    todo = FakeTodo.new

    result = ShoppingListPublisher.new(todo: todo).publish

    assert_equal [ "tahini" ], result.added
  end

  test "previews without writing anything" do
    todo = FakeTodo.new(existing: [ "eggs" ])

    result = ShoppingListPublisher.new(todo: todo).preview

    assert_equal [ "tahini" ], result.added
    assert_equal [ "eggs" ], result.skipped
    assert_empty todo.added
  end

  test "does nothing when Home Assistant is not configured" do
    todo = FakeTodo.new(configured: false)

    result = ShoppingListPublisher.new(todo: todo).publish

    assert_not result.configured?
    assert_empty todo.added
    assert_match(/not configured/i, result.summary)
  end
end

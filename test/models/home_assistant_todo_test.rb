require "test_helper"

class HomeAssistantTodoTest < ActiveSupport::TestCase
  # Stands in for the HTTP transport, recording calls and replaying canned
  # responses — the same "inject a fake at the real dependency" approach
  # RecipeImporter uses for pages.
  class FakeTransport
    attr_reader :posts, :gets

    def initialize(responses = {})
      @responses = responses
      @posts = []
      @gets = []
    end

    def get(path)
      @gets << path
      @responses.fetch(path, {})
    end

    def post(path, body)
      @posts << [ path, body ]
      @responses.fetch(path, {})
    end
  end

  def build(transport, **overrides)
    HomeAssistantTodo.new(
      **{ base_url: "http://ha.test:8123", token: "t", entity_id: "todo.shopping_list", transport: transport }.merge(overrides)
    )
  end

  test "is unconfigured without a base url or token" do
    assert_not build(FakeTransport.new, token: nil).configured?
    assert_not build(FakeTransport.new, base_url: "").configured?
    assert build(FakeTransport.new).configured?
  end

  test "reads outstanding items" do
    transport = FakeTransport.new(
      "/api/services/todo/get_items?return_response" => {
        "service_response" => { "todo.shopping_list" => { "items" => [
          { "uid" => "abc", "summary" => "eggs", "status" => "needs_action" }
        ] } }
      }
    )

    items = build(transport).open_items

    assert_equal 1, items.size
    assert_equal "eggs", items.first.summary
    assert_equal "abc", items.first.uid
    assert_equal({ entity_id: "todo.shopping_list", status: "needs_action" }, transport.posts.first.last)
  end

  test "treats an empty response as an empty list" do
    assert_empty build(FakeTransport.new).open_items
  end

  test "sends a description when the entity supports one" do
    transport = FakeTransport.new("/api/states/todo.shopping_list" => { "attributes" => { "supported_features" => 127 } })

    build(transport).add(summary: "tahini", description: "200 g")

    assert_equal({ entity_id: "todo.shopping_list", item: "tahini", description: "200 g" }, transport.posts.last.last)
  end

  # The legacy shopping_list integration reports 15 and answers a description
  # with HTTP 500 rather than ignoring it.
  test "omits the description when the entity does not support one" do
    transport = FakeTransport.new("/api/states/todo.shopping_list" => { "attributes" => { "supported_features" => 15 } })

    build(transport).add(summary: "tahini", description: "200 g")

    assert_equal({ entity_id: "todo.shopping_list", item: "tahini" }, transport.posts.last.last)
  end

  test "checks supported features only once" do
    transport = FakeTransport.new("/api/states/todo.shopping_list" => { "attributes" => { "supported_features" => 127 } })
    todo = build(transport)

    3.times { todo.supports_description? }

    assert_equal 1, transport.gets.size
  end

  test "clears completed items through the generic todo service" do
    transport = FakeTransport.new

    assert build(transport).clear_completed
    assert_equal "/api/services/todo/remove_completed_items", transport.posts.last.first
    assert_equal({ entity_id: "todo.shopping_list" }, transport.posts.last.last)
  end
end

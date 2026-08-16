require "net/http"
require "json"

# A Home Assistant to-do list, over the REST API.
#
# Deliberately written against the generic `todo` domain rather than any one
# integration: todo.get_items / todo.add_item behave identically across
# local_todo, shopping_list, Bring!, Todoist, CalDAV and Google Tasks, so this
# points at whatever list an operator already keeps.
#
# Everything install-specific is env, because this repo is public:
#
#   HA_BASE_URL          http://192.168.0.96:8123   (use the IP — a hostname
#                        routes a same-subnet call through a reverse proxy)
#   HA_TOKEN             a long-lived access token
#   HA_TODO_ENTITY       todo.shopping_list
#
# Give the token its own non-admin HA user. Long-lived tokens carry their
# owner's permissions, so an owner token would hand nosh the whole house.
class HomeAssistantTodo
  class Error < StandardError; end

  # TodoListEntityFeature.SET_DESCRIPTION. The legacy `shopping_list`
  # integration reports 15 and returns HTTP 500 rather than ignoring a
  # description, so this is detected at runtime instead of configured.
  SET_DESCRIPTION = 64

  Item = Struct.new(:uid, :summary, :status, :description, keyword_init: true)

  def self.from_env(transport: nil)
    new(
      base_url: ENV["HA_BASE_URL"],
      token: ENV["HA_TOKEN"],
      entity_id: ENV["HA_TODO_ENTITY"].presence || "todo.shopping_list",
      transport: transport
    )
  end

  attr_reader :entity_id

  def initialize(base_url:, token:, entity_id:, transport: nil)
    @base_url = base_url.to_s.chomp("/")
    @token = token
    @entity_id = entity_id
    @transport = transport
  end

  # nosh runs perfectly well with no Home Assistant at all; callers check this
  # rather than rescuing a connection error.
  def configured? = @base_url.present? && @token.present?

  def open_items
    response = transport.post("/api/services/todo/get_items?return_response", { entity_id: entity_id, status: "needs_action" })
    items = response.dig("service_response", entity_id, "items") || []
    items.map { |item| Item.new(uid: item["uid"], summary: item["summary"], status: item["status"], description: item["description"]) }
  end

  def add(summary:, description: nil)
    payload = { entity_id: entity_id, item: summary }
    payload[:description] = description if description.present? && supports_description?
    transport.post("/api/services/todo/add_item", payload)
    true
  end

  def supports_description?
    return @supports_description unless @supports_description.nil?

    features = transport.get("/api/states/#{entity_id}").dig("attributes", "supported_features").to_i
    @supports_description = features.anybits?(SET_DESCRIPTION)
  end

  private

  def transport = @transport ||= Net.new(@base_url, @token)

  # The real HTTP transport. Tests pass their own object responding to
  # #get/#post instead — nosh has no mocking library by design.
  class Net
    def initialize(base_url, token)
      @base_url = base_url
      @token = token
    end

    def get(path) = request(::Net::HTTP::Get.new(uri_for(path)))

    def post(path, body)
      request = ::Net::HTTP::Post.new(uri_for(path))
      request.body = body.to_json
      request(request)
    end

    private

    def uri_for(path) = URI.parse("#{@base_url}#{path}")

    def request(request)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"

      response = ::Net::HTTP.start(request.uri.hostname, request.uri.port, read_timeout: 15) { |http| http.request(request) }
      raise Error, "#{request.uri.path} returned #{response.code}" unless response.is_a?(::Net::HTTPSuccess)

      response.body.presence ? JSON.parse(response.body) : {}
    rescue ::Net::OpenTimeout, ::Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise Error, "Home Assistant unreachable: #{e.class}"
    end
  end
end

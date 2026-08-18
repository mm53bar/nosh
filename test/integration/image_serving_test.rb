require "test_helper"

# Image bytes leave nosh by one specific path, and two of its properties are
# load-bearing but invisible to an ordinary assertion about a response body.
#
# 1. Active Storage's *proxy* controller includes ActionController::Live; its
#    *disk* controller does not. Live drops Content-Length on the first write and
#    hands the body to a second thread that checks out its own database
#    connection. Both broke verso in production. nosh avoids them by leaving
#    resolve_model_to_route at Rails' default, :rails_storage_redirect.
# 2. Rack::Sendfile only acts on a body that responds to #to_path. The disk
#    controller's does (Rack::Files::Iterator aliases it); a streaming one never
#    would. That is what lets Thruster serve the file with sendfile(2).
#
# Neither survives a refactor unless something asserts the *mechanism*. A body
# assertion cannot see either one: the integration harness computes a
# Content-Length whether the controller supplied one or not.
class ImageServingTest < ActionDispatch::IntegrationTest
  setup do
    @recipe = recipes(:one)
    @recipe.image.attach(
      io: file_fixture("recipe.jpg").open, filename: "recipe.jpg", content_type: "image/jpeg"
    )
  end

  test "images route through the redirect controller, not the streaming proxy" do
    # The effective value, not config.active_storage's, which stays nil when
    # unset — ActiveStorage::Engine resolves the default onto the module.
    assert_equal :rails_storage_redirect, ActiveStorage.resolve_model_to_route,
      "Proxy mode puts every image on ActionController::Live — see " \
      "docs/adr/20260818-named-variants-so-they-can-be-warmed.md"

    get rails_blob_path(@recipe.image, disposition: "inline")

    assert_response :redirect
    assert_match %r{/rails/active_storage/disk/}, response.location
  end

  # Rack::Sendfile reads sendfile.type from the Rack env as well as from config,
  # so one request can opt in even though x_sendfile_header is production-only.
  test "a blob response hands the proxy a path instead of streaming bytes" do
    get rails_blob_path(@recipe.image, disposition: "inline")
    get response.location, headers: { "sendfile.type" => "X-Sendfile" }

    assert_response :success
    assert response.headers["X-Sendfile"].present?,
      "the disk controller must give Rack a body responding to #to_path"
  end

  # The control for the test above: without it, that assertion would also pass
  # against a controller that never handed Rack anything, and we would not know.
  test "a rendered HTML response has no path to hand over" do
    get recipes_path, headers: { "sendfile.type" => "X-Sendfile" }

    assert_response :success
    assert_nil response.headers["X-Sendfile"]
  end
end

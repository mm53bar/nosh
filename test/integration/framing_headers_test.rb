require "test_helper"

# nosh is embedded in a Home Assistant dashboard on the kitchen screen, which
# only works if it stops sending X-Frame-Options and names the framer via CSP
# instead. The policy is application-wide, so /recipes exercises it as well as
# anything. See docs/adr/20260812-framed-by-home-assistant.md.
class FramingHeadersTest < ActionDispatch::IntegrationTest
  test "no X-Frame-Options header — it would override frame-ancestors" do
    get recipes_path

    assert_response :success
    assert_nil response.headers["X-Frame-Options"]
  end

  test "frame-ancestors is same-origin only when NOSH_FRAME_ANCESTORS is unset" do
    get recipes_path

    assert_equal "frame-ancestors 'self'", response.headers["Content-Security-Policy"]
  end

  # The policy is built from ENV at boot, so this exercises the directive the
  # initializer constructs rather than re-booting the app with the var set.
  test "configured origins are appended to 'self'" do
    policy = ActionDispatch::ContentSecurityPolicy.new
    policy.frame_ancestors :self, *Nosh.frame_ancestors("https://hass.example, http://10.0.0.1:8123")

    assert_equal "frame-ancestors 'self' https://hass.example http://10.0.0.1:8123", policy.build
  end

  test "frame ancestor parsing tolerates blanks and stray whitespace" do
    assert_equal [], Nosh.frame_ancestors(nil)
    assert_equal [], Nosh.frame_ancestors("")
    assert_equal [], Nosh.frame_ancestors(" , ")
    assert_equal [ "https://a.example", "https://b.example" ], Nosh.frame_ancestors("  https://a.example ,https://b.example ")
  end

  test "no other CSP directives are set — they would break the importmap" do
    get recipes_path

    refute_includes response.headers["Content-Security-Policy"], "script-src"
    refute_includes response.headers["Content-Security-Policy"], "default-src"
  end
end

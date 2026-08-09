require "test_helper"

# Rails disables CSRF enforcement globally in the test environment
# (config.action_controller.allow_forgery_protection = false), so exercising
# this at all means turning it back on for just these two tests.
class CsrfProtectionTest < ActionDispatch::IntegrationTest
  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }

  test "JSON requests are not required to carry a CSRF token" do
    post recipes_path, params: { recipe: { title: "No Token Needed" } }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :created
  end

  test "HTML form requests without a CSRF token are still rejected" do
    post recipes_path, params: { recipe: { title: "Should Be Blocked" } }

    assert_response :unprocessable_entity
  end
end

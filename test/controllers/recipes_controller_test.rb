require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  test "index renders with sidebar facet options computed from the loaded recipes" do
    get recipes_path
    assert_response :success
    assert_select "input[data-facet='cuisine'][value=?]", recipes(:one).cuisine
  end

  test "index.json still supports query-param filtering for API consumers" do
    get recipes_path(cuisine: recipes(:one).cuisine), as: :json
    body = JSON.parse(response.body)

    assert(body.all? { |r| r["cuisine"] == recipes(:one).cuisine })
  end

  test "import redirects with an error for an invalid URL, with no network access needed" do
    post import_recipes_path, params: { url: "javascript:alert(1)" }

    assert_redirected_to recipes_path
    assert_equal "Invalid URL — must be http:// or https://", flash[:alert]
  end
end

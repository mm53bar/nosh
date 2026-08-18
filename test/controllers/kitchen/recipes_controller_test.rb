require "test_helper"

class Kitchen::RecipesControllerTest < ActionDispatch::IntegrationTest
  setup { @recipe = recipes(:one) }

  test "show puts ingredients and steps on the page together" do
    get kitchen_recipe_path(@recipe)

    assert_response :success
    assert_select "aside", text: /#{ingredients(:one).name}/
    assert_select "li.step", count: @recipe.steps.count
  end

  test "show carries a way back and none of the app's edit affordances" do
    get kitchen_recipe_path(@recipe)

    assert_select "a[href=?]", kitchen_root_path
    assert_select "a[href=?]", edit_recipe_path(@recipe), count: 0
    assert_select "a[href=?]", recipes_path, count: 0
  end

  test "made records today and reports the new label" do
    @recipe.update!(last_made_on: nil)

    post made_kitchen_recipe_path(@recipe), as: :json

    assert_response :success
    assert_equal Date.current, @recipe.reload.last_made_on
    assert_equal "Made today", response.parsed_body["label"]
  end

  # The kiosk's parent page is a different site, so no session cookie and no
  # CSRF token reach the iframe — the write has to go over JSON to be exempt.
  test "made needs no CSRF token, since the framed page can't have one" do
    ActionController::Base.allow_forgery_protection = true

    post made_kitchen_recipe_path(@recipe), as: :json

    assert_response :success
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  # There's no way to re-enter a URL on the kiosk, so the theme has to ride
  # along on every link out of this page or the cook lands on a white screen.
  test "show keeps the theme on its way back" do
    get kitchen_recipe_path(@recipe, theme: "dark")

    assert_select "html.theme-dark"
    assert_select "a[href=?]", kitchen_root_path(theme: "dark")
  end

  # Home Assistant's corner button leaves nosh; this one goes up a level inside
  # it. Both have to be on screen, so nosh's says where it goes in words rather
  # than being a second bare arrow next to the host's.
  test "the way back is a labelled link, not a bare glyph" do
    get kitchen_recipe_path(@recipe)

    assert_select "a[href=?]", kitchen_root_path, text: /This week/
  end

  test "embed reserves the corner without dropping the way back" do
    get kitchen_recipe_path(@recipe, embed: "1")

    assert_select "header.ps-\\[74px\\].min-h-\\[74px\\]"
    assert_select "a[href=?]", kitchen_root_path(embed: "1"), text: /This week/
  end

  test "the corner is only reserved when the dashboard asks for it" do
    get kitchen_recipe_path(@recipe)

    assert_select "header.ps-\\[74px\\]", count: 0
    assert_select "header.ps-6"
  end
end

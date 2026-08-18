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

  # You're at the bottom of the method by the time this is true, not at the top
  # of the page — and how long ago it was last made is a fact about some other
  # day, not something the screen you're cooking from needs.
  test "made it sits at the end of the method, and nothing tracks the last time" do
    get kitchen_recipe_path(@recipe)

    assert_select "section [data-action=?]", "made-it#mark"
    assert_select "header button", count: 0
    assert_select "body", text: /Never made|Last made/, count: 0
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

  # The framed viewport is ~534px tall, so the header is one row and the numbers
  # live in the panes they describe rather than in a line of their own.
  test "servings and time sit with the ingredients and the method" do
    get kitchen_recipe_path(@recipe)

    assert_select "aside", text: /4 servings/
    assert_select "section", text: /30m/
    assert_select "header", text: /4 servings/, count: 0
  end

  # Home Assistant's corner button leaves nosh; this one goes up a level inside
  # it. Both have to be on screen, so nosh's says where it goes in words rather
  # than being a second bare arrow next to the host's.
  test "the way back is a labelled link, not a bare glyph" do
    get kitchen_recipe_path(@recipe)

    assert_select "a[href=?]", kitchen_root_path, text: /This week/
  end

  # The corner the host's button covers has to hold nothing that needs reading
  # or tapping. A photo satisfies that better than blank space, so a recipe with
  # an image puts the dish there and only an image-less one falls back to the
  # blank reserve.
  test "a recipe with a photo puts it in the corner instead of reserving it" do
    # The bytes are never decoded here — the view only builds a variant URL —
    # so a stand-in blob is enough to exercise the branch.
    @recipe.image.attach(io: StringIO.new("not really a jpeg"), filename: "photo.jpg", content_type: "image/jpeg")

    get kitchen_recipe_path(@recipe, embed: "1")

    assert_select "header figure img"
    assert_select "header.ps-\\[74px\\]", count: 0
    assert_select "a[href=?]", kitchen_root_path(embed: "1"), text: /This week/
  end

  test "a recipe with no photo falls back to reserving the corner" do
    get kitchen_recipe_path(@recipe, embed: "1")

    assert_select "header figure", count: 0
    assert_select "header.ps-\\[74px\\].min-h-\\[74px\\]"
  end

  test "the corner is only reserved when the dashboard asks for it" do
    get kitchen_recipe_path(@recipe)

    assert_select "header.ps-\\[74px\\]", count: 0
    assert_select "header.ps-6"
  end
end

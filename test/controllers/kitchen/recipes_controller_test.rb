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
  # or tapping. The photo at the top of the ingredients column satisfies that,
  # so this screen reserves nothing — but the block has to be there even when
  # the recipe has no picture, or the button lands on the ingredient list.
  test "the dish sits in the corner the host's button covers" do
    # The bytes are never decoded here — the view only builds a variant URL —
    # so a stand-in blob is enough to exercise the branch.
    @recipe.image.attach(io: StringIO.new("not really a jpeg"), filename: "photo.jpg", content_type: "image/jpeg")

    get kitchen_recipe_path(@recipe, embed: "1")

    assert_select "aside figure.aspect-video img"
    assert_select "a[href=?]", kitchen_root_path(embed: "1"), text: /This week/
  end

  test "a recipe with no photo still gives the button something to land on" do
    get kitchen_recipe_path(@recipe, embed: "1")

    assert_select "aside figure.h-\\[78px\\]"
    assert_select "aside figure img", count: 0
  end

  # The switch that stops the kiosk navigating away mid-recipe. It's the last
  # thing in the Method row because the progress readout next to it changes
  # width as steps get ticked off, and a control that moves is a control you
  # mis-tap with a floury finger. See
  # docs/adr/20260821-keep-awake-is-two-backends.md.
  test "the method row ends with the keep-awake switch" do
    get kitchen_recipe_path(@recipe)

    assert_select "[data-controller=wake-lock]", text: /Keep awake/ do
      assert_select "input[type=checkbox][data-wake-lock-target=toggle][data-action=?]", "change->wake-lock#toggle"
    end
    assert_select "div.flex > *:last-child[data-controller=wake-lock]"
  end

  # Same rule the browse UI's show page has always had: no steps, nothing to
  # hold the screen for.
  test "no keep-awake switch on a recipe with no steps" do
    @recipe.steps.destroy_all

    get kitchen_recipe_path(@recipe)

    assert_response :success
    assert_select "[data-controller=wake-lock]", count: 0
  end

  # Nothing on this screen is indented for the button, embedded or not — the
  # photo is what keeps the corner clear.
  test "the recipe screen reserves no blank corner either way" do
    get kitchen_recipe_path(@recipe, embed: "1")
    assert_select ".ps-\\[74px\\]", count: 0

    get kitchen_recipe_path(@recipe)
    assert_select ".ps-\\[74px\\]", count: 0
  end

  # Revealed by the controller once a backend answers, so a bundle that never
  # loads leaves no switch rather than one that does nothing.
  test "the keep-awake switch is hidden until JS reveals it" do
    get kitchen_recipe_path(@recipe)

    assert_select "[data-controller=wake-lock][hidden]"
  end
end

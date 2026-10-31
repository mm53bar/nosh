require "test_helper"

class RecipeCandidateTest < ActiveSupport::TestCase
  PROPOSAL = {
    "is_recipe" => true, "name" => "Bean Toast", "recipeYield" => "2", "totalTime" => "PT15M",
    "recipeCategory" => "Snack", "keywords" => [ "beans" ],
    "recipeIngredient" => [ "1 can white beans, drained", "2 slices bread" ],
    "recipeInstructions" => [ "Warm the beans.", "Pile them on toast." ],
    "vegetarian" => true, "not_vegetarian" => []
  }.freeze

  def candidate(**attrs)
    RecipeCandidate.create!(origin: "youtube", source_url: "https://www.youtube.com/watch?v=H8p8xj0bqew",
                            title: "A Can of Beans", source_text: "transcript", **attrs)
  end

  test "a usable answer makes it ready for review" do
    c = candidate
    c.extract!(FakeLlm.new(PROPOSAL))

    assert c.ready?
    assert c.recipe?
    assert_equal 1, c.attempts
    assert_equal "Bean Toast", c.proposal["name"]
  end

  test "a not-a-recipe answer is ready too, so a person sees the reason" do
    c = candidate
    c.extract!(FakeLlm.new("is_recipe" => false, "skip_reason" => "equipment review"))

    assert c.ready?
    assert_not c.recipe?
    assert_equal "equipment review", c.skip_reason
  end

  test "an unusable answer spends an attempt, and the last one fails it" do
    c = candidate
    llm = FakeLlm.new("is_recipe" => true, "recipeIngredient" => [])

    c.extract!(llm)
    assert c.queued?
    c.extract!(llm)
    c.extract!(llm)

    assert c.failed?
    assert_equal 3, c.attempts
    assert_includes RecipeCandidate.awaiting_review, c
  end

  test "an outage raises and spends no attempt" do
    c = candidate

    assert_raises(LlmClient::Unavailable) { c.extract!(FakeLlm.new(LlmClient::Unavailable.new("429"))) }
    assert c.reload.queued?
    assert_equal 0, c.attempts
  end

  test "meat warnings combine the model's list with a word check" do
    c = candidate(proposal: PROPOSAL.merge(
      "recipeIngredient" => [ "1 tbsp fish sauce", "2 cups vegetable broth", "1 cup chicken stock", "1 can beans" ],
      "not_vegetarian" => [ "1 tbsp fish sauce" ]
    ))

    assert_equal [ "1 tbsp fish sauce", "1 cup chicken stock" ], c.meat_warnings
  end

  test "builds an unsaved recipe from the proposal" do
    recipe = candidate(proposal: PROPOSAL).build_recipe

    assert recipe.new_record?
    assert_equal "Bean Toast", recipe.title
    assert_equal "https://www.youtube.com/watch?v=H8p8xj0bqew", recipe.source_url
    assert_equal 2, recipe.servings
    assert_equal 15, recipe.total_time_minutes
    assert_equal [ "white beans", "bread" ], recipe.ingredients.map(&:name)
    assert_equal "1 can white beans, drained", recipe.ingredients.first.original_text
    assert_equal 2, recipe.steps.size
  end

  test "a failed candidate still builds a recipe titled after the video" do
    assert_equal "A Can of Beans", candidate(status: :failed).build_recipe.title
  end

  test "accepting saves the recipe and links it" do
    c = candidate(proposal: PROPOSAL)
    recipe = c.build_recipe

    assert c.accept(recipe)
    assert c.reload.accepted?
    assert_equal recipe, c.recipe
    assert_not_includes RecipeCandidate.awaiting_review, c
  end

  test "an invalid recipe is not accepted" do
    c = candidate(proposal: PROPOSAL)
    recipe = c.build_recipe
    recipe.title = ""

    assert_not c.accept(recipe)
    assert c.reload.queued?
    assert recipe.new_record?
  end
end

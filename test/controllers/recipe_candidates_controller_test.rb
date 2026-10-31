require "test_helper"

class RecipeCandidatesControllerTest < ActionDispatch::IntegrationTest
  test "every page shows what's waiting for review" do
    get recipes_path

    assert_select "a[href=?]", recipe_candidate_path(recipe_candidates(:puffs)), text: "Review"
  end

  test "lists what's waiting" do
    get recipe_candidates_path

    assert_response :success
    assert_select "li", text: /Spinach Puffs/
  end

  test "the review is the recipe form, filled from the proposal" do
    get recipe_candidate_path(recipe_candidates(:puffs))

    assert_response :success
    assert_select "form[action=?]", accept_recipe_candidate_path(recipe_candidates(:puffs))
    assert_select "input[name='recipe[title]'][value='Spinach Puffs']"
    assert_select "input[name*='[original_text]'][value='2 cups spinach, chopped']"
  end

  test "warns when a line may not be vegetarian" do
    candidate = recipe_candidates(:puffs)
    candidate.update!(proposal: candidate.proposal.merge("recipeIngredient" => [ "4 anchovies" ]))
    get recipe_candidate_path(candidate)

    assert_select "div", text: /may not be vegetarian/i
  end

  test "accepting adds the recipe as the reviewer left it" do
    candidate = recipe_candidates(:puffs)
    assert_difference -> { Recipe.count } do
      post accept_recipe_candidate_path(candidate), params: { recipe: {
        title: "Spinach Puffs", source_url: candidate.source_url,
        ingredients_attributes: { "0" => { name: "spinach", amount: "2", unit: "cups", original_text: "2 cups spinach, chopped" } },
        steps_attributes: { "0" => { instruction: "Bake." } }
      } }
    end

    recipe = Recipe.last
    assert_redirected_to recipe
    assert candidate.reload.accepted?
    assert_equal recipe, candidate.recipe
    assert_equal "2 cups spinach, chopped", recipe.ingredients.first.original_text
  end

  test "an invalid recipe re-renders the review" do
    post accept_recipe_candidate_path(recipe_candidates(:puffs)), params: { recipe: { title: "" } }

    assert_response :unprocessable_entity
    assert recipe_candidates(:puffs).reload.ready?
  end

  test "discarding takes it off the list" do
    post discard_recipe_candidate_path(recipe_candidates(:puffs))

    assert_redirected_to recipe_candidates_path
    assert recipe_candidates(:puffs).reload.discarded?
  end

  test "scanning queues the import job" do
    assert_enqueued_with(job: YoutubeImportJob) { post scan_recipe_candidates_path }
  end
end

require "test_helper"

class DinnerSlateTest < ActiveSupport::TestCase
  WEEK = Date.new(2026, 11, 2)

  setup do
    travel_to Date.new(2026, 10, 31)
    MealPlanEntry.delete_all
    Recipe.destroy_all
  end

  def answer(*recipes, extra: [])
    { "ideas" => recipes.map { |recipe| { "id" => recipe.id.to_s, "complexity" => "quick", "why" => "Uses the chickpeas." } } + extra }
  end

  def dinner(title, **attrs) = Recipe.create!(title: title, meal_type: "Dinner", **attrs)

  test "the pool leaves out what was cooked or planned lately, and anything that isn't dinner" do
    fresh = dinner("Fresh")
    dinner("Cooked last week", last_made_on: Date.current - 7)
    planned = dinner("Planned next week")
    MealPlanEntry.create!(date: WEEK + 2, recipe: planned)
    Recipe.create!(title: "Cake", meal_type: "Dessert")
    untyped = Recipe.create!(title: "No type")
    excluded = dinner("Shown already")

    pool = DinnerSlate.pool(WEEK, excluding: [ excluded.id ])

    assert_includes pool, fresh
    assert_includes pool, untyped
    assert_equal [], pool.map(&:title) & [ "Cooked last week", "Planned next week", "Cake", "Shown already" ]
  end

  test "keeps only ids from the pool, once each" do
    a = dinner("Chana Masala")
    b = dinner("Tofu Pad Thai")
    llm = FakeLlm.new(answer(a, b, a, extra: [ { "id" => 999_999 }, "junk" ]))

    slate = DinnerSlate.suggest(WEEK, llm: llm)

    assert slate.ready?
    assert_equal [ a.id, b.id ], slate.ideas.map { |idea| idea["recipe_id"] }
    assert_equal "quick", slate.ideas.first["complexity"]
    assert slate.new_record?
  end

  test "too few usable picks is a failure, after one retry" do
    dinner("Anything")
    llm = FakeLlm.new("ideas" => [ { "id" => 999_999 } ])

    slate = DinnerSlate.suggest(WEEK, llm: llm)

    assert slate.failed?
    assert_match "didn't pick enough", slate.error
    assert_equal 2, llm.calls
  end

  test "an outage raises" do
    dinner("Anything")

    assert_raises(LlmClient::Unavailable) { DinnerSlate.suggest(WEEK, llm: FakeLlm.new(LlmClient::Unavailable.new("429"))) }
  end

  test "suggesting again keeps ideas already planned and never repeats the rest" do
    planned = dinner("Planned")
    dropped = dinner("Dropped")
    fresh = dinner("Fresh")
    slate = DinnerSlate.create!(week_start: WEEK, status: :ready,
                                ideas: [ { "recipe_id" => planned.id }, { "recipe_id" => dropped.id } ])
    MealPlanEntry.create!(date: WEEK, recipe: planned)

    again = slate.suggest_again(llm: FakeLlm.new(answer(dropped, fresh)))

    assert again.persisted?
    assert_equal [ planned.id, fresh.id ], again.ideas.map { |idea| idea["recipe_id"] }
    assert_equal again, DinnerSlate.current(WEEK)
  end

  test "a failed suggest-again leaves the current slate showing" do
    slate = DinnerSlate.create!(week_start: WEEK, status: :ready, ideas: [ { "recipe_id" => dinner("Kept").id } ])

    again = slate.suggest_again(llm: FakeLlm.new("ideas" => []))

    assert again.failed?
    assert_equal slate, DinnerSlate.current(WEEK)
  end

  test "suggestions skip a recipe deleted since" do
    gone = dinner("Gone")
    slate = DinnerSlate.create!(week_start: WEEK, status: :ready, ideas: [ { "recipe_id" => gone.id, "why" => "x" } ])
    gone.destroy

    assert_empty slate.suggestions
  end

  test "announced until seen, and a failure until replaced" do
    slate = DinnerSlate.create!(week_start: WEEK, status: :ready, ideas: [])
    assert_equal slate, DinnerSlate.to_announce

    slate.seen!
    assert_nil DinnerSlate.to_announce

    failed = DinnerSlate.create!(week_start: WEEK, status: :failed, error: "down")
    assert_equal failed, DinnerSlate.to_announce
  end

  test "a past week's slate isn't announced" do
    DinnerSlate.create!(week_start: WEEK - 14, status: :ready, ideas: [])

    assert_nil DinnerSlate.to_announce
  end
end

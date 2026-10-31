require "test_helper"

class DinnerSlateJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  setup do
    travel_to Date.new(2026, 10, 31) # a Saturday
    MealPlanEntry.delete_all
  end

  def llm = FakeLlm.new("ideas" => [ { "id" => recipes(:one).id }, { "id" => recipes(:two).id } ])

  test "makes next week's slate" do
    DinnerSlateJob.perform_now(llm: llm)

    slate = DinnerSlate.sole
    assert slate.ready?
    assert_equal Date.new(2026, 11, 2), slate.week_start
  end

  test "a week that already has ideas costs nothing" do
    DinnerSlate.create!(week_start: Date.new(2026, 11, 2), status: :ready, ideas: [])
    fake = llm
    DinnerSlateJob.perform_now(llm: fake)

    assert_equal 0, fake.calls
    assert_equal 1, DinnerSlate.count
  end

  test "keeps a failed slate so the banner says so" do
    DinnerSlateJob.perform_now(llm: FakeLlm.new("ideas" => []))

    assert DinnerSlate.sole.failed?
  end

  test "does nothing without a model" do
    DinnerSlateJob.perform_now(llm: LlmClient.new(base_url: nil, model: nil))

    assert_equal 0, DinnerSlate.count
  end

  test "suggesting again replaces the ideas not yet planned" do
    week = Date.new(2026, 11, 2)
    DinnerSlate.create!(week_start: week, status: :ready, ideas: [ { "recipe_id" => recipes(:one).id } ])
    DinnerSlateJob.perform_now(week_start: week, again: true, llm: FakeLlm.new("ideas" => [ { "id" => recipes(:two).id } ]))

    assert_equal [ recipes(:two).id ], DinnerSlate.current(week).ideas.map { |idea| idea["recipe_id"] }
  end

  test "a failed suggest-again keeps the ideas and says why" do
    week = Date.new(2026, 11, 2)
    slate = DinnerSlate.create!(week_start: week, status: :ready, ideas: [ { "recipe_id" => recipes(:one).id } ])
    DinnerSlateJob.perform_now(week_start: week, again: true, llm: FakeLlm.new("ideas" => []))

    assert_equal slate, DinnerSlate.current(week)
    assert_match "didn't pick enough", slate.reload.error
  end

  test "the page refreshes when it's done" do
    assert_broadcasts("dinner_slates", 1) { DinnerSlateJob.perform_now(llm: llm) }
  end
end

require "test_helper"

class DinnerSlateJobTest < ActiveJob::TestCase
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
end

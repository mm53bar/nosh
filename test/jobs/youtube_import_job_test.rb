require "test_helper"

class YoutubeImportJobTest < ActiveJob::TestCase
  DIR = Rails.root.join("test/fixtures/files/clippings").to_s
  PROPOSAL = { "is_recipe" => true, "recipeIngredient" => [ "1 cup spinach" ], "recipeInstructions" => [ "Bake." ] }.freeze

  setup { RecipeCandidate.delete_all }

  test "queues each new recipe video once and reads it" do
    llm = FakeLlm.new(PROPOSAL)
    YoutubeImportJob.perform_now(dir: DIR, llm: llm)

    assert_equal [ "https://www.youtube.com/watch?v=x5-QoCicNfI" ], RecipeCandidate.pluck(:source_url)
    candidate = RecipeCandidate.sole
    assert candidate.ready?
    assert_equal "https://i.ytimg.com/vi/x5-QoCicNfI/hqdefault.jpg", candidate.image_url
    assert_equal 1, llm.calls
  end

  test "a second run costs nothing" do
    YoutubeImportJob.perform_now(dir: DIR, llm: FakeLlm.new(PROPOSAL))
    llm = FakeLlm.new(PROPOSAL)
    YoutubeImportJob.perform_now(dir: DIR, llm: llm)

    assert_equal 1, RecipeCandidate.count
    assert_equal 0, llm.calls
  end

  test "skips a video already in the collection, however its link is written" do
    recipes(:one).update!(source_url: "https://youtu.be/x5-QoCicNfI")
    YoutubeImportJob.perform_now(dir: DIR, llm: FakeLlm.new(PROPOSAL))

    assert_equal 0, RecipeCandidate.count
  end

  test "a discarded video is not suggested again" do
    RecipeCandidate.create!(origin: "youtube", source_url: "https://www.youtube.com/watch?v=x5-QoCicNfI", status: :discarded)
    llm = FakeLlm.new(PROPOSAL)
    YoutubeImportJob.perform_now(dir: DIR, llm: llm)

    assert_equal 0, llm.calls
  end

  test "an outage leaves the video queued for tomorrow" do
    YoutubeImportJob.perform_now(dir: DIR, llm: FakeLlm.new(LlmClient::Unavailable.new("429")))

    assert RecipeCandidate.sole.queued?
  end

  test "does nothing without a folder or a model" do
    YoutubeImportJob.perform_now(dir: nil, llm: FakeLlm.new(PROPOSAL))
    YoutubeImportJob.perform_now(dir: DIR, llm: LlmClient.new(base_url: nil, model: nil))

    assert_equal 0, RecipeCandidate.count
  end
end

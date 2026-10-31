require "test_helper"

class YoutubeClippingTest < ActiveSupport::TestCase
  DIR = Rails.root.join("test/fixtures/files/clippings").to_s

  test "reads the frontmatter and keeps the transcript as the body" do
    clipping = YoutubeClipping.new(File.join(DIR, "spinach-puffs.md"))

    assert_equal "Binging with Babish: Spinach Puffs", clipping.title
    assert_equal "Binging with Babish", clipping.channel
    assert_equal "x5-QoCicNfI", clipping.video_id
    assert_equal "https://www.youtube.com/watch?v=x5-QoCicNfI", clipping.source_url
    assert_includes clipping.body, "puff pastry"
    assert_not_includes clipping.body, "tags:"
  end

  test "a short link names the same video" do
    clipping = YoutubeClipping.new(File.join(DIR, "spinach-puffs-retitled.md"))

    assert_equal "https://www.youtube.com/watch?v=x5-QoCicNfI", clipping.source_url
  end

  test "recipes_in finds only recipes-tagged videos" do
    names = YoutubeClipping.recipes_in(DIR).map { |clipping| File.basename(clipping.path) }

    assert_equal %w[already-added.md spinach-puffs-retitled.md spinach-puffs.md], names
  end

  test "a file stamped by the old script was handled there" do
    assert YoutubeClipping.new(File.join(DIR, "already-added.md")).handled_elsewhere?
    assert_not YoutubeClipping.new(File.join(DIR, "spinach-puffs.md")).handled_elsewhere?
  end

  test "a file without frontmatter is not a recipe" do
    assert_not YoutubeClipping.new("x.md", "just text").recipe?
  end

  test "recipes_in is empty for a missing folder" do
    assert_empty YoutubeClipping.recipes_in("/nonexistent")
    assert_empty YoutubeClipping.recipes_in(nil)
  end
end

require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "current returns a singleton row, creating it exactly once" do
    Setting.delete_all
    first  = Setting.current
    second = Setting.current
    assert_equal first.id, second.id
    assert_equal 1, Setting.count
  end

  test "effective_flaresolverr_url prefers the stored value over the env var" do
    Setting.current.update!(flaresolverr_url: "http://db.example:8191")
    with_env("FLARESOLVERR_URL", "http://env.example:8191") do
      assert_equal "http://db.example:8191", Setting.current.effective_flaresolverr_url
    end
  end

  test "effective_flaresolverr_url falls back to the env var when blank" do
    Setting.current.update!(flaresolverr_url: "")
    with_env("FLARESOLVERR_URL", "http://env.example:8191") do
      assert_equal "http://env.example:8191", Setting.current.effective_flaresolverr_url
    end
  end

  test "effective_flaresolverr_url is nil when neither is set — the feature is simply off" do
    Setting.current.update!(flaresolverr_url: nil)
    with_env("FLARESOLVERR_URL", nil) do
      assert_nil Setting.current.effective_flaresolverr_url
    end
  end

  private

  def with_env(key, value)
    original = ENV[key]
    value.nil? ? ENV.delete(key) : ENV[key] = value
    yield
  ensure
    original.nil? ? ENV.delete(key) : ENV[key] = original
  end
end

class Setting < ApplicationRecord
  # The app has exactly one settings row. `Setting.current` returns it,
  # creating it on first access — call sites should always go through
  # `Setting.current` rather than querying Setting directly.
  def self.current
    first_or_create!
  end

  # Falls back to FLARESOLVERR_URL when no value is saved yet, so a deployment
  # can bootstrap via env and later move the value in here without a redeploy.
  # Blank (the default) just means the FlareSolverr-dependent features are off
  # — it's optional, not required to run the app.
  def effective_flaresolverr_url
    flaresolverr_url.presence || ENV["FLARESOLVERR_URL"].presence
  end
end

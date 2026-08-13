require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Nosh
  # Kiosk browsers commonly serve their dashboard from a port on the device
  # itself, so the page framing nosh is a loopback origin whose port belongs to
  # whichever kiosk app is installed. Allowing loopback outright means a kiosk
  # needs no configuration at all. It grants little: a page can only claim this
  # origin by already running on the viewer's own machine.
  LOOPBACK_FRAME_ANCESTORS = %w[http://127.0.0.1:* http://localhost:*].freeze

  # Origins allowed to embed nosh in an iframe, from a comma-separated env var.
  # Empty (the default) means same-origin only. Feeds CSP's frame-ancestors —
  # see docs/adr/20260812-framed-by-home-assistant.md.
  def self.frame_ancestors(value = ENV["NOSH_FRAME_ANCESTORS"])
    value.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Secrets come from the environment: SECRET_KEY_BASE (required; Rails 8.1
    # resolves ENV["SECRET_KEY_BASE"] before consulting credentials). This repo
    # is public, so config/credentials.yml.enc is never committed — Rails'
    # conventional encrypted credentials still work as an escape hatch but are
    # not required to boot. See docs/adr/20260809-secrets-from-env.md.

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = ENV.fetch("TZ", "UTC")

    # Rails defaults to X-Frame-Options: SAMEORIGIN, which has no multi-origin
    # form and which browsers won't let you combine with CSP frame-ancestors.
    # The kitchen screen has to be framable by Home Assistant, so the header
    # goes and frame-ancestors takes over — see the initializer, and
    # docs/adr/20260812-framed-by-home-assistant.md.
    config.action_dispatch.default_headers.delete("X-Frame-Options")

    # The running build's git SHA — written into REVISION/REVISION_SHORT by the
    # Docker build (absent in dev, so it falls back to "dev"). Shown in the
    # footer so you can tell which build is live.
    revision       = Rails.root.join("REVISION")
    revision_short = Rails.root.join("REVISION_SHORT")
    config.x.git_sha       = revision.exist?       ? revision.read.strip       : "dev"
    config.x.git_sha_short = revision_short.exist? ? revision_short.read.strip : "dev"

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

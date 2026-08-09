require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Nosh
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

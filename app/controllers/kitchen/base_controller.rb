module Kitchen
  # Shared setup for the kitchen wall screen: its own chrome-free layout, and
  # nothing that escapes into the main app. There's no browser back button on
  # the kiosk, so every screen carries its own navigation.
  class BaseController < ApplicationController
    layout "kitchen"

    # The wall screen sits in a Home Assistant dashboard that's themed dark, and
    # a white page beside it is a lamp. `?theme=dark` / `?theme=light` force one;
    # anything else — including no param at all — is "auto", which defers to the
    # device's own dark-mode setting via `prefers-color-scheme`. Auto is the
    # default because it degrades to today's light screen on a WebView that
    # doesn't report a colour scheme, which is what the Echo Show may well do.
    THEMES = %w[light dark].freeze

    helper_method :kitchen_theme

    private

      def kitchen_theme
        THEMES.find { |theme| theme == params[:theme] } || "auto"
      end

      # There's no browser chrome on the kiosk and no way to re-type a URL, so a
      # theme set on the dashboard's URL has to survive every tap. Home Assistant
      # only ever needs to put `?theme=` on the one page it embeds.
      def default_url_options
        kitchen_theme == "auto" ? {} : { theme: kitchen_theme }
      end
  end
end

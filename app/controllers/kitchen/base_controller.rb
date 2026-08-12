module Kitchen
  # Shared setup for the kitchen wall screen: its own chrome-free layout, and
  # nothing that escapes into the main app. There's no browser back button on
  # the kiosk, so every screen carries its own navigation.
  class BaseController < ApplicationController
    layout "kitchen"
  end
end

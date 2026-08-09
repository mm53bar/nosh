class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # CSRF tokens are session-scoped and browsers-only; JSON API clients (nanoclaw's
  # scripts, the ingredient-audit skill, etc.) have no session to carry one in.
  # There's no auth to protect here either way — see docs/adr/20260809-no-auth-needed.md.
  protect_from_forgery with: :exception, unless: -> { request.format.json? }
end

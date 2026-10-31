class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # CSRF tokens are session-scoped and browsers-only; JSON API clients (nanoclaw's
  # scripts, the ingredient-audit skill, etc.) have no session to carry one in.
  # There's no auth to protect here either way — see docs/adr/20260809-no-auth-needed.md.
  #
  # A JSON *body* counts as well as a `.json` path. Without this, a caller that
  # posts JSON to a path with no suffix is treated as an HTML form submission
  # and gets a 422 CSRF **HTML error page** — which once silently broke one of
  # nanoclaw's writes. A cross-origin
  # form cannot set this content type without a CORS preflight, so honouring it
  # gives up nothing.
  protect_from_forgery with: :exception, unless: -> { json_request? }

  private

  def json_request?
    request.format.json? || request.media_type&.include?("json")
  end
end

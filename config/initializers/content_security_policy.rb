# Be sure to restart your server when you modify this file.

# nosh sets exactly one CSP directive: frame-ancestors, which replaces the
# X-Frame-Options header removed in config/application.rb. It names the origins
# allowed to embed nosh in an iframe — the household's Home Assistant kiosk, in
# practice. Everything else is deliberately left unset: adding default_src or
# script_src here would break the importmap and Turbo setup, and nosh has no
# untrusted content to defend against. See
# docs/adr/20260812-framed-by-home-assistant.md.
#
# NOSH_FRAME_ANCESTORS is a comma-separated origin list. Unset (the default)
# means 'self' alone, so nothing changes for anyone deploying nosh without it.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.frame_ancestors :self, *Nosh.frame_ancestors
  end
end

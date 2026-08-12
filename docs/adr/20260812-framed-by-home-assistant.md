# 20260812 — Let Home Assistant frame nosh

## Context

The kitchen is getting a wall screen: a first-generation Echo Show 8, jailbroken to LineageOS,
running as a Home Assistant dashboard and voice satellite. The point of it is cooking from nosh
without carrying an iPad to the counter. Home Assistant embeds nosh in an iframe on one of its
dashboard views.

That didn't work. Rails ships `X-Frame-Options: SAMEORIGIN` in
`config.action_dispatch.default_headers`, so the iframe rendered an empty box. The header has no
multi-origin form — it's `DENY`, `SAMEORIGIN`, or nothing — and browsers reject the combination of
`X-Frame-Options` and CSP `frame-ancestors`, so loosening it in place isn't available. It has to go.

Removing it touches the reasoning in `20260809-no-auth-needed.md`, which rests on nosh being
unreachable from outside the household. Framing doesn't change reachability, but it does mean nosh
now names an origin it trusts to embed it, which is a trust relationship the app didn't have before.

## Decision

Drop `X-Frame-Options` and set CSP `frame-ancestors` instead, from a comma-separated
`NOSH_FRAME_ANCESTORS` env var. Unset — the default, and what `compose.yaml` ships — means
`frame-ancestors 'self'`, so nothing changes for anyone deploying nosh without setting it.

`frame-ancestors` is the only directive in the policy. `default_src` and `script_src` would break
the importmap and Turbo setup, and there is no untrusted content in nosh to defend against with
them.

The policy is application-wide rather than scoped to `/kitchen`. Scoping it would be a false
economy: the same screen will plausibly want the shopping list next, and a per-controller policy is
more machinery than the risk warrants on a LAN-only app.

## Consequences

- A named external origin can now embed any nosh page, including the edit forms. On a household
  LAN with no auth, the marginal clickjacking risk over "anyone on the LAN can just open nosh
  directly" is close to nil.
- **Writes from inside the iframe can't rely on the session.** The kiosk loads Home Assistant from
  a bare LAN IP, which is a different *site* from nosh's hostname — not merely a different origin.
  Chrome drops the `SameSite=Lax` session cookie in that context, and third-party cookie
  restrictions would drop it even at `SameSite=None`. So no CSRF token reaches the page and no
  flash survives the redirect. `/kitchen`'s one write ("made it") goes through the JSON endpoint,
  which `ApplicationController` already exempts from forgery protection, and reports success by
  updating the button in place. Any future kitchen write has to work the same way.
- The env var wants the origin of the **parent** page, not of nosh, with scheme and port. Getting
  it wrong fails the same way as having no header at all: an empty box, no console-obvious cause.
- The operational rule from the no-auth ADR is unchanged and now matters slightly more: nosh must
  not be deployed anywhere publicly reachable.

## Alternatives considered

- **Strip the header at the Caddy layer instead.** Rejected: Caddy fronts several apps, the header
  is Rails' to send, and a proxy-level override is invisible to anyone reading this repo. It also
  wouldn't help the case where the kiosk reaches the origin server directly.
- **Scope the CSP to `/kitchen` only.** Rejected as above — real added complexity, negligible risk
  reduction on a LAN-only app with no login.
- **Reverse-proxy nosh under Home Assistant's own origin** so the frame is same-origin and the
  cookie problem disappears. Rejected: it means maintaining a proxy route inside Home Assistant,
  and it entangles two apps' URL spaces to avoid one env var.

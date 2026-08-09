# 20260809 — No authentication

## Context

`blip` and `tsundoku` both trust forward-auth headers (`Remote-User` etc.) from an upstream
Authelia proxy, because both show data that varies per signed-in user — blip's reminders belong to
one person, tsundoku's reading/shelf state belongs to one person. nosh has no such per-user data:
recipes, the meal plan, and the shopping list are shared household state with no owner. The
deployment target, `recipes.backson.boo`, also resolves only internally (via this household's
Caddy instance) — there's no public exposure to defend against.

## Decision

nosh ships with no authentication at all: no `User` model, no login flow, no proxy-header
trust model. Every request is treated as coming from a trusted household member.

## Consequences

- Simpler than blip/tsundoku in one respect: no `ApplicationController#require_authentication`,
  no dev-login bypass, no `User.find_or_provision_from_proxy`.
- The app must never be deployed somewhere it's actually publicly reachable. `compose.yaml`'s
  header comment says so explicitly; this is an operational responsibility, not something the app
  enforces itself.
- If a future feature needs per-person state (e.g. "who's cooking tonight" assignments, or
  personal recipe ratings), that's the trigger to revisit this decision — not before.

## Alternatives considered

- **Reuse blip/tsundoku's Authelia proxy-auth pattern anyway, for consistency.** Rejected: it adds
  a `User` model, a trust boundary, and a dev-login bypass for a household app with no per-user
  data to protect — pure ceremony with no corresponding benefit here.

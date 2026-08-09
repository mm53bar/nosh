# nosh — agent guidance

> *Nosh*: informal slang for food — short, plain, no metaphor required.

A self-hosted Rails app for a household's recipes, weekly meal planning, and the shopping list
that falls out of it. Rebuilt from an earlier Node/Express app (`mm53bar/recipes-app`) to match
the conventions of this operator's other Rails apps, `blip` and `tsundoku`. This file is standing
rules, not a spec — read the code and `docs/adr/` for the actual design.

## Standing rules

- Prefer Rails conventions over architecture-heavy patterns. Reach for a plain model/job before a
  new abstraction. No `app/services/` directory — extract nouns (`ShoppingListBuilder`), not verbs.
- No authentication. This app has no login system, no `User` model, no roles — see
  `docs/adr/20260809-no-auth-needed.md`. It must only ever run somewhere that isn't publicly
  reachable (see `compose.yaml`'s header comment). Don't add proxy-auth scaffolding "just in
  case" — add it only if the deployment model actually changes.
- The JSON API follows normal Rails resourceful conventions (same URLs as the HTML routes, format
  negotiated via `.json` / `Accept`) — it does **not** byte-match the old Express app's `/api/*`
  paths. Nanoclaw's consumer scripts (recipe-discovery, the ingredient-audit skill, the meal-plan
  slate builder) were written against the old paths and need updating to match; don't contort
  routes/controllers to avoid that. See `docs/adr/20260809-idiomatic-api-not-byte-compatible.md`.
- Tags are a real `tags` + `recipe_tags` join, not the old app's free-text column — `Recipe#tag_names`/
  `#tag_names=` gives API/form callers an array-of-strings interface over that join without them
  needing to know it's relational underneath.
- Recipe photos are Active Storage attachments (`has_one_attached :image`), fetched by URL
  (`POST /recipes/:id/image`) or uploaded directly as the `image` param on create/update — no
  hand-rolled upload path or `data/images/` directory like the old app.
- Any feature that needs FlareSolverr (or another external service) to work around a
  Cloudflare-protected site must be optional and configured through the in-app Settings page, not
  a required env var — see `docs/adr/20260809-settings-in-database.md`. Nothing in this app
  requires FlareSolverr as of the initial build; the setting is infrastructure for whenever a
  future feature (e.g. porting nanoclaw's recipe-discovery scraper into the app) needs it.
- Secrets are a plain **env var** (`SECRET_KEY_BASE`) — this repo is public, so
  `config/credentials.yml.enc` is git-ignored and never committed; env is the blessed source,
  Rails encrypted credentials remain an optional escape hatch. See
  `docs/adr/20260809-secrets-from-env.md`. Never commit a real secret; `compose.yaml` carries
  placeholders only.
- Deployment is a single container: web + Solid Queue run together in Puma
  (`config/puma.rb`, gated on `RAILS_ENV=production`) — no separate worker service, no Redis.
- Testing: Minitest with fixtures. No RSpec, no factories, no mocking library, no
  Capybara/system-test harness (skipped from the start — see tsundoku's own regret ADR on this).
- Significant architectural decisions are recorded in `docs/adr/` (`## Context` / `## Decision` /
  `## Consequences` / `## Alternatives considered`). Read that directory before assuming a design
  decision hasn't been made yet. See also `plan.md` for the phased build plan.

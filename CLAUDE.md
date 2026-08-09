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
- UI components come from **Rails Blocks** (railsblocks.com — the operator has a Pro account;
  ask if a component looks paywalled) — check `tsundoku`'s `app/views/shared/components/` first,
  since it's already copied a lot of what nosh needs. Retint from the default blue/neutral to
  nosh's stone/amber palette when pulling one in. Don't copy interaction JS (e.g. the navbar's
  dropdown controller) for behavior the page doesn't actually use — that's exactly the kind of
  unused scaffolding tsundoku's own history warns against.
- No manual "add a recipe" form linked from the UI (the old app didn't have one either — recipes
  arrive via migration or LLM-driven discovery adding through the JSON API). The one add path in
  the UI is pasting a source URL, which `RecipeImporter` resolves by reading the page's embedded
  schema.org/Recipe JSON-LD (the same structured data nosh's own show page emits). `/recipes/new`
  still works as a manual fallback, just isn't linked anywhere.
- The recipe list's search/sidebar filtering is entirely client-side
  (`recipe_filter_controller.js`) over the full preloaded card grid — no Turbo Frame round-trip.
  Fine at this scale (~150 recipes); revisit if the collection grows enough for that to matter.
- No Settings model/page. Finding new recipes from external sites is nanoclaw's/the LLM
  automation layer's job (`recipe-discovery.py`), not this app's — there's nothing in nosh that
  needs FlareSolverr or similar, so don't add operator-settings infrastructure ahead of an actual
  need. See `docs/adr/20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`.
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

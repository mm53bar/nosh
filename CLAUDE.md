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
- `Equipment` (name + owned, seeded from the household's real kitchen in `db/seeds.rb`) and
  `Technique` (title + body, freeform reference/technique content — not shaped like a Recipe) are
  real models, not tags. Equipment is create-on-the-fly by name (`HasEquipment` concern, shared by
  Recipe and Technique); Techniques are only ever linked to a recipe by picking an existing one
  (`technique_ids`) — never create-on-the-fly, since a stub with no `body` is worthless. See
  `docs/adr/20260809-equipment-and-technique-models.md`.
- Secrets are a plain **env var** (`SECRET_KEY_BASE`) — this repo is public, so
  `config/credentials.yml.enc` is git-ignored and never committed; env is the blessed source,
  Rails encrypted credentials remain an optional escape hatch. See
  `docs/adr/20260809-secrets-from-env.md`. Never commit a real secret; `compose.yaml` carries
  placeholders only.
- Ingredient `name` is the **shopping label**; package sizes, prep and substitutions go in
  `note`. `Ingredient` splits a freeform name on create when no note is given, so API callers
  can post a raw scraped line — don't add splitting logic to callers. `bin/rails
  ingredients:lint` reports what still needs a human. See
  `docs/adr/20260815-ingredient-name-is-the-shopping-label.md`.
- The shopping list **publishes to a Home Assistant to-do list** and is not meant to be read in
  nosh — `POST /shopping_list/publish` ("lock it in"), one entry point for both the UI and an API
  caller. Publishing removes **bought** items first (`todo.remove_completed_items`) then adds
  what's missing — otherwise last week's purchase suppresses this week's genuine need for the
  same ingredient. Outstanding items, whoever added them, are never touched and the list is never
  bulk-replaced. Publish **once per plan**: a second run after a shop re-adds the whole trip. Categories and ordering belong to HA, which sorts by a
  hidden due date and categorises every item whoever added it — don't send a category or compute
  a sort key here. All config is env (`HA_*`), and nosh works normally with none of it set. See
  `docs/adr/20260815-shopping-list-publishes-to-home-assistant.md`.
- The kitchen wall screen themes from the URL: `?theme=dark` / `?theme=light`, anything else (or
  nothing) meaning auto via `prefers-color-scheme`. `dark:` is an **opt-in** Tailwind variant keyed
  to a `theme-*` class the kitchen layout sets, so it never fires on the browse UI — every kitchen
  colour utility needs its own `dark:` counterpart. See
  `docs/adr/20260817-kitchen-screen-theme-param.md`.
- `?embed=1` on a kitchen URL means Home Assistant is drawing its own back button over the
  top-left corner, so the screen leaves a 74px square there empty in **both** axes
  (`kitchen_corner_reserve`, which owns the geometry for every kitchen screen — don't reach back
  into it with a negative margin). Like `?theme=`, it rides along on every link via
  `default_url_options`. The rule is that nothing of nosh's in that square may need reading or
  tapping — the recipe screen satisfies it with the dish photo under the button rather than with
  blank space, at the top of its left column (two columns top to bottom, verso's shape). nosh's own in-app navigation stays inside nosh's content and carries a label
  (`‹ This week`) rather than being a second bare arrow in the host's corner. The framed viewport
  is **853×533 CSS px**, not 1280×800: both kitchen headers are one row, and the week's grid is
  tuned so all seven days clear the fold with 5.5px to spare — re-measure before growing a card or
  a header. See `docs/adr/20260817-kitchen-embed-reserves-the-corner.md`.
- **"Keep awake" is one switch over two backends**, and `checked` means "at least one hold is
  active" — a Screen Wake Lock for an iPad, and a lease relayed by the host page for the kiosk,
  whose app-level return-home timer no web API can reach. Inside the frame the wake lock always
  fails, so never let a failing backend un-check the switch, and test availability by *acquiring*
  one rather than checking `"wakeLock" in navigator` (which is true there and lies). The switch
  is gated on capability, never on `?embed=1`, and renewal deliberately continues while the page
  is hidden. The message contract is shared with the `homeassistant` repo, so it's versioned and
  can't be changed one-sidedly; `test/harness/keep_awake_host.html` is a fake host to drive it
  against, outside the suite on purpose. See
  `docs/adr/20260821-keep-awake-is-two-backends.md`.
- Deployment is a single container: web + Solid Queue run together in Puma
  (`config/puma.rb`, gated on `RAILS_ENV=production`) — no separate worker service, no Redis.
- Testing: Minitest with fixtures. No RSpec, no factories, no mocking library, no
  Capybara/system-test harness (skipped from the start — see tsundoku's own regret ADR on this).
- Significant architectural decisions are recorded in `docs/adr/` (`## Context` / `## Decision` /
  `## Consequences` / `## Alternatives considered`). Read that directory before assuming a design
  decision hasn't been made yet. See also `plan.md` for the phased build plan.

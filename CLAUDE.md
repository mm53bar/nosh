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
  Install components with the `rails-blocks` CLI (already signed in with Pro):
  `rails-blocks install NAME --as partial --path app/views/shared/components`. Only the slice of
  Rails Blocks' installation CSS those components need is in `application.css`, with `primary`
  mapped to amber, and its checkbox styling is scoped to a `.rails-blocks` wrapper so the
  kitchen screen's measured checkboxes keep their native look.
- No manual "add a recipe" form linked from the UI (the old app didn't have one either). The add
  paths in the UI are reviewing a `RecipeCandidate` (below) and pasting a source URL, which
  `RecipeImporter` resolves by reading the page's embedded schema.org/Recipe JSON-LD (the same structured data nosh's own show page emits). `/recipes/new`
  still works as a manual fallback, just isn't linked anywhere.
- The recipe list's search/sidebar filtering is entirely client-side
  (`recipe_filter_controller.js`) over the full preloaded card grid — no Turbo Frame round-trip.
  Fine at this scale (~150 recipes); revisit if the collection grows enough for that to matter.
- **`Setting` holds what the household edits in the app**, one row via `Setting.current`, named
  columns only (today: `dinner_slate_notes`). Add a column when something real needs one, not
  ahead of it. Household data goes there or in the DB, never in the repo. See
  `docs/adr/20261031-household-settings-in-the-database.md`.
- **Recipes found automatically wait for review as `RecipeCandidate`s**, never as `Recipe`s.
  `YoutubeImportJob` reads the YouTube Recipes playlist's transcripts daily from
  `YOUTUBE_CLIPPINGS_PATH` (mounted read-only) and makes one LLM call per video through
  `LlmClient` (`LLM_BASE_URL` / `LLM_MODEL`). The proposal is a schema.org/Recipe node, so
  `RecipeImporter#build` makes it a recipe. A person adds or discards each one from the banner
  under the header. Identify a video by its id, never the clipping's filename. Don't let anything
  add a candidate to the collection without that review. See
  `docs/adr/20261030-recipe-candidates-wait-for-review.md`.
- **The week's dinner ideas are a `DinnerSlate`**, made Saturday 8am by `DinnerSlateJob` and
  shown on the Meal Plan page, where each goes on a night beside anything else. Ruby builds the
  pool, and the model only chooses from it by id. Household specifics go in
  `Setting#dinner_slate_notes`, never in the prompt in the repo. Picking never publishes the shopping
  list. A `MealPlanEntry` may be a `title` with no recipe, so read `entry.name`, not
  `entry.recipe.title`. See `docs/adr/20261030-dinner-ideas-on-the-meal-plan.md`.
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
- Ingredient and shopping-list **amounts are numbers** (`amount`, plus `amount_max` for a
  range). Assign any written form and `HasAmount` parses it; show one with `display_amount` or
  `quantity`, never the raw column. Don't format or parse amounts anywhere else. See
  `docs/adr/20261025-amounts-are-stored-as-numbers.md`.
- **Recipes scale with `?servings=N`** on both recipe pages, rendered on the server inside a
  `turbo_frame_tag "ingredients"`. Pass a scale to `quantity`/`display_amount`, never multiply
  and format yourself. See `docs/adr/20261025-servings-scale-on-the-server.md`.
- **`IngredientAlias` renames on record and applies on create**, exact names only, never on
  update. The ingredient audit is the one caller (`POST /ingredient_aliases.json`). See
  `docs/adr/20261025-ingredient-aliases-apply-on-create.md`.
- **`Ingredient#original_text` is written once**, on create, and a parser change is re-run
  against it. See `docs/adr/20261025-ingredients-keep-their-original-line.md`.
- **A recipe keeps the page it came from** (`source_page`, gzipped; `source_data` for the
  JSON-LD node). nosh never fetches it outside `RecipeImporter`; other callers upload it to
  `POST /recipes/:id/source.json`, with `lines` when the page's JSON-LD has none. Site-specific
  scraping stays with the caller. See `docs/adr/20261025-recipes-keep-their-source-page.md`.
- The shopping list is a **staples board owned by nosh**: tabs (`Staple`, grouped by `Aisle`)
  flipped on when something runs out, write-ins (`WriteIn`) for anything else typed in, and the
  meal plan's "this week" lines. **Voice can only flip tabs** — `POST /staples/need` / `have`
  with a spoken `item`, answered with a `speech` string nosh writes. An unknown item is refused,
  never written in. **The meal plan never flips a tab**: a staple ingredient becomes a marker on
  it (`ShoppingListItem#staple`). A group word ("cheese", "oil") names several tabs and never
  flips any of them, and can't be a tab itself. `StapleMatcher` is the one place names are
  resolved, for voice, the typed box and the plan alike — don't match names anywhere else. The
  board's contents are household data and stay out of `db/seeds.rb`. **nosh never writes to Home
  Assistant**: the board is the only list, and HA only calls `need`/`have`/`GET
  /shopping_list.json`. See `docs/adr/20261031-home-assistant-push-removed.md` and
  `docs/adr/20261018-shopping-list-is-a-staples-board.md`.
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
- The kiosk's shopping view is **`/kitchen/shopping_list`**: every tab on one 853×533 screen,
  one row per aisle, tapped to flip, with write-ins, no typing and no "this week" lines. It
  clears the fold by 30.6px with three write-ins. Re-measure before growing it. See
  `docs/adr/20261031-kitchen-shopping-board.md`.
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

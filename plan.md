# nosh — Rails recipes/meal-plan/shopping-list app

Rebuild of `mm53bar/recipes-app` (Node/Express, ~1,400 lines, no separate frontend) as a Rails app
matching the conventions of `blip` and `tsundoku`. Household-scale: ~130 recipes, no per-user data,
no public exposure (see `docs/adr/20260809-no-auth-needed.md`).

## Decisions locked in

- **Stack:** Rails 8.1.3 / Ruby 3.4.7 (pinned via `.mise.toml`). SQLite. Propshaft. Tailwind CSS
  v4. Hotwire (Turbo/Stimulus) via importmap. Solid Queue/Cache/Cable (no Redis) — Solid Queue's
  supervisor runs inside Puma in production, same as blip.
- **View layer:** ERB partials + Stimulus controllers. No ViewComponent, no `app/services/`.
- **Testing:** Minitest with fixtures. No RSpec, no factories, no mocks, no Capybara/system tests
  (skipped from the start, per tsundoku's own regret ADR on unused system-test scaffolding).
- **Auth:** none — see `docs/adr/20260809-no-auth-needed.md`.
- **Data model:** `Recipe` has_many `ingredients`/`steps`/`tags` (through a real `recipe_tags`
  join — the old app used a free-text tag column; fixed here since it's a cheap improvement),
  `has_many :meal_plan_entries`. `ShoppingListItem` is a flat aggregate row, rebuilt wholesale by
  `ShoppingListBuilder` (a PORO, not a controller method) whenever the meal plan changes.
  `Setting` is a singleton row for optional operator config (currently just
  `flaresolverr_url` — see `docs/adr/20260809-settings-in-database.md`).
- **Images:** Active Storage (`has_one_attached :image` on `Recipe`), fetched by URL or uploaded
  directly — no hand-rolled `data/images/` directory like the old app.
- **JSON API:** idiomatic Rails resourceful routes, not byte-compatible with the old `/api/*`
  paths — see `docs/adr/20260809-idiomatic-api-not-byte-compatible.md`. Nanoclaw's consumer
  scripts need updating before they can talk to nosh.
- **Secrets:** plain env var (`SECRET_KEY_BASE`) — see `docs/adr/20260809-secrets-from-env.md`.
- **Deployment:** single container (web + Solid Queue in Puma), multi-stage Dockerfile + Thruster,
  published to GHCR by GitHub Actions on push to `main`, run via Arcane on Jumbo exactly like the
  old app — same bind-mount-for-storage pattern as blip/tsundoku.

## Phase 0 — Rails skeleton — DONE

- App generated (Rails 8.1.3, Tailwind, importmap, Hotwire, Solid Queue/Cache/Cable wired up with
  the multi-database `production` section and the in-Puma Solid Queue plugin, matching blip).
- Data model: `Recipe`, `Ingredient`, `Step`, `Tag`/`RecipeTag`, `MealPlanEntry`,
  `ShoppingListItem`, `Setting` — migrated, validated, fixtured, tested.
- `ShoppingListBuilder` ported from the old app's `generateShoppingList` (servings-scaled
  ingredient aggregation across a meal-plan date range) — tested against the exact scaling case.
- Controllers + views for recipes (full CRUD, nested ingredients/steps via a hand-rolled
  add/remove Stimulus controller — no cocoon gem), meal plan (weekly grid, add/remove entries),
  shopping list (generate from a date range, per-item check-off, clear), settings
  (FlareSolverr URL). JSON views (jbuilder) alongside the HTML ones for every resource.
- Verified end-to-end by hand: created a recipe with nested ingredients/steps through the HTML
  form, planned it with a servings override, generated the shopping list, confirmed the scaled
  quantity came out correct.
- Deployment files: Dockerfile (multi-stage, host-agnostic UID via compose `user:`), compose.yaml
  template, CI (brakeman/bundler-audit/importmap-audit/rubocop/minitest) and GHCR build workflows,
  dependabot. All CI checks pass locally as of this writing (0 Brakeman warnings after fixing one
  real finding — see below).
- One real security fix from Brakeman's first pass: `Recipe#source_url` is rendered in a
  `link_to` href, so it got a format validation (`\Ahttps?://\S+\z`) rejecting `javascript:`/other
  schemes — not just an ignored warning.

## Phase 1 — Not yet built

- **Faceted client-side filtering** on the recipe list (type/effort/rating/cuisine/last-made,
  matching the old app's sidebar) — current index view only does a server-side title search.
  Old app also had this as vanilla JS; a Stimulus controller is the natural port.
- **PWA shell** (manifest + service worker) and the recipe-detail Wake Lock "keep screen on while
  cooking" toggle — both present in the old app, not yet ported.
- **Raw image upload UI polish** — the backend already accepts `image` as a multipart param on
  create/update (Active Storage handles it natively); the HTML form has a plain file field but no
  drag-and-drop or preview.
- **Data migration** from the live old app (or its SQLite file) into nosh — one-time script,
  ~130 recipes, needs to preserve the ingredient-naming cleanup already done (see the main
  `recipes` project's `CLAUDE.md`).
- **Update nanoclaw's consumer scripts** (`recipe-discovery.py`, `build_slate.py`, the
  `ingredient-audit` skill) to point at nosh's actual routes/field names once it's deployed.
- **Public GitHub repo + first deploy** — not done yet; confirm with the operator before creating
  the repo or pushing (this app was deliberately scaffolded in a fresh directory, separate from
  the `recipes` ops workspace, specifically so nothing sensitive rides along into a public repo).

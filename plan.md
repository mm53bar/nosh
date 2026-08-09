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
  No `Setting`/operator-config model — recipe discovery (the one feature that would have needed
  one) is nanoclaw's job, not nosh's. See `docs/adr/20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`.
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
  `ShoppingListItem` — migrated, validated, fixtured, tested.
- `ShoppingListBuilder` ported from the old app's `generateShoppingList` (servings-scaled
  ingredient aggregation across a meal-plan date range) — tested against the exact scaling case.
- Controllers + views for recipes (full CRUD, nested ingredients/steps via a hand-rolled
  add/remove Stimulus controller — no cocoon gem), meal plan (weekly grid, add/remove entries),
  shopping list (generate from a date range, per-item check-off, clear). JSON views (jbuilder)
  alongside the HTML ones for every resource.
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
- Embedded schema.org/Recipe JSON-LD on the recipe show page (`RecipesHelper#recipe_structured_data`)
  — chosen over the long-dead hRecipe microformat; this is what recipe-import tools/search engines
  actually read today, and it became the basis for `RecipeImporter` below.

## Phase 1 — Deployed, then a UI/UX pass — DONE

- **Public GitHub repo + first deploy**: `mm53bar/nosh`, public, GHCR image builds on push to
  `main`. Deployed via Arcane on Jumbo (port 3213, storage at `/volume1/docker/nosh/data`),
  fronted by `nosh.backson.boo` in Caddy — a parallel/staging domain; `recipes.backson.boo` still
  points at the old app until nosh is trusted enough to take it over.
- **Data migration**: all 133 recipes copied from the live old app via
  `~/projects/recipes/reference-scripts/migrate-to-nosh-2026-08-09.py`, verified byte-for-byte
  (counts, ratings, cuisines, images all matched, including a genuine duplicate-titled recipe).
- **Real bug found via deployment, fixed**: Rails' default CSRF protection doesn't exempt JSON
  requests, so every API write 422'd until `ApplicationController` scoped `protect_from_forgery`
  to HTML only (`unless: -> { request.format.json? }`).
- **UI overhaul to actually match blip/tsundoku**, prompted by direct feedback that the first pass
  didn't:
  - Recipe cards use Rails Blocks' "Card with Featured Image" component (railsblocks.com/docs/card),
    retinted to nosh's stone/amber palette.
  - Nav uses the Rails Blocks navbar structural component (copied from tsundoku, which already has
    it from railsblocks.com) — but *not* its ~1000-line dropdown/mobile-hamburger JS controller,
    since nosh has neither dropdowns nor enough nav items to need a hamburger. Active-page
    highlighting added to the item partial.
  - Footer with the git SHA/commit link, matching blip/tsundoku exactly.
  - Recipe list got a real sidebar (cuisine, meal type, an effort bucket derived from
    `total_time_minutes`, rating) plus debounced live search and a clear button — all client-side
    over the preloaded card grid (`recipe_filter_controller.js`), matching how the old app's list
    actually worked. No page reload, no Enter key needed.
  - Default sort switched from alphabetical to `created_at desc` ("when added").
  - Removed the `Setting`/`flaresolverr_url` model entirely — recipe discovery is nanoclaw's/the
    LLM layer's job, not this app's, so there was never anything that would read that setting. See
    `docs/adr/20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`.
  - Removed the "+ New Recipe" button (the old app never had manual-add UI either) and replaced it
    with a "paste a URL" import: `RecipeImporter` fetches the source page and reads its embedded
    schema.org/Recipe JSON-LD — the same structured data nosh's own show page now emits. Verified
    against a real recipe (re-imported one of nosh's own live pages end-to-end). hRecipe support
    deliberately skipped — dead format, not worth the parser.

## Phase 2 — Not yet built

- **PWA shell** (manifest + service worker) and the recipe-detail Wake Lock "keep screen on while
  cooking" toggle — both present in the old app, not yet ported.
- **Raw image upload UI polish** — the backend already accepts `image` as a multipart param on
  create/update (Active Storage handles it natively); the HTML form has a plain file field but no
  drag-and-drop or preview.
- **Update nanoclaw's consumer scripts** (`recipe-discovery.py`, `build_slate.py`, the
  `ingredient-audit` skill) to point at nosh's actual routes/field names.
- **Cutover**: repoint `recipes.backson.boo` at nosh, retire the old `recipes-app` container/Arcane
  project — once nosh is trusted enough. Needs a separate explicit go-ahead.

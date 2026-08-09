# 20260809 — The JSON API follows Rails conventions, not the old app's byte-compatible shape

## Context

The old Node/Express recipes-app exposed a hand-rolled JSON API at `/api/recipes`,
`/api/meal-plan`, `/api/shopping-list`, `/api/shopping-list-items/:id`,
`/api/shopping-list/categories`, and `/api/stats`. Three pieces of household automation on the
nanoclaw VM call these endpoints directly: `recipe-discovery.py`, the weekly meal-plan slate
builder (`build_slate.py`), and this project's own `ingredient-audit` skill. A rewrite could try
to reproduce those exact paths and payload shapes so nothing else has to change.

## Decision

Don't. The JSON API is the same resourceful routes as the HTML app, differentiated by
`Accept`/`.json` — `GET/POST /recipes`, `GET/PATCH/DELETE /recipes/:id`,
`GET/POST /meal_plan_entries`, `DELETE /meal_plan_entries/:id`, `GET/DELETE /shopping_list`,
`POST /shopping_list/generate`, `PATCH /shopping_list_items/:id`,
`PATCH /shopping_list_items/bulk_update`, `GET /stats`. Field names use idiomatic Rails naming
(`prep_time_minutes` not `prep_time`, `last_made_on` not `last_made`, tags as a real array
resolved through a join table) rather than mirroring the old schema.

The explicit tradeoff, agreed with the app's operator: build a clean Rails API first: update the
nanoclaw scripts to match if/when they're pointed at nosh, rather than contorting routes,
controller actions, or param names to preserve the old contract.

## Consequences

- `recipe-discovery.py`, `build_slate.py`, and the `ingredient-audit` skill will all need their
  `RECIPES_URL` request paths and payload field names updated before they can talk to nosh instead
  of the old app. This is expected, tracked work — not a regression to avoid.
- New consumers get a normal, guessable Rails API instead of a bespoke one.

## Alternatives considered

- **Byte-compatible `/api/*` shim.** Rejected per explicit operator direction: not worth deviating
  from Rails norms (kebab-case paths, non-idiomatic field names) to avoid a one-time update to
  three known scripts.

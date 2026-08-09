# 20260809 — Operator settings live in the database, not just env

> **Superseded the same day** by
> [`20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`](20260809-no-settings-recipe-discovery-is-nanoclaws-job.md).
> The premise below (nosh might eventually need FlareSolverr for its own recipe-discovery feature)
> turned out to be wrong — that feature belongs to nanoclaw/the LLM layer, not this app. Kept for
> the record of what was considered; the `Setting` model, `settings` table, and this decision are
> reverted.

## Context

Some recipe sites (HelloFresh CA, Chef's Plate) sit behind Cloudflare and block plain HTTP
requests; the household's existing nanoclaw automation gets past that with a self-hosted
FlareSolverr instance. If a future nosh feature needs the same trick (e.g. porting that
recipe-discovery scraper into the app itself, or fetching a source-page image through it), that
integration must not become a hard dependency — most of what nosh does (recipes, meal plan,
shopping list) has nothing to do with FlareSolverr, and most self-hosted deployments of this app
won't have one running.

## Decision

Introduce a single-row `Setting` model (mirroring tsundoku's own
`docs/adr/20260628-settings-in-database.md`) for exactly this kind of optional, operator-editable
runtime configuration:

- `Setting.current` returns the one settings row (`first_or_create!`). Call sites go through it;
  nobody queries `Setting` directly.
- `effective_flaresolverr_url` falls back to `ENV["FLARESOLVERR_URL"]` when no value is saved in
  the UI, so a deployment can bootstrap via env and later move the value into Settings without a
  redeploy.
- Blank (the default, in both the column and the env var) just means the FlareSolverr-dependent
  feature is off. Nothing in the app requires it to boot or to serve recipes/meal-plan/shopping-list.

As of this initial build, nothing in nosh actually calls `effective_flaresolverr_url` yet — the
setting is infrastructure laid down ahead of the feature that will need it, per the explicit
requirement that any such integration be optional and configurable, not a required env var.

## Consequences

- Operators can turn on a FlareSolverr-dependent feature later without editing `compose.yaml`.
- The same `Setting` model is the home for any future operator-editable runtime config (matching
  tsundoku's guidance) — resist turning it into a generic key/value settings framework; add typed
  columns for real, named settings.

## Alternatives considered

- **Env var only (`FLARESOLVERR_URL`).** Rejected: changing it means editing the compose file and
  redeploying, which is heavier than it needs to be for a value with no security sensitivity.
- **Build the recipe-discovery scraper now, since we're touching this anyway.** Rejected: out of
  scope for the initial Rails rebuild — that feature currently lives in nanoclaw's
  `discover.py` and works; porting it is a separate decision with its own tradeoffs (a background
  job, FlareSolverr client code, site-parsing logic) that shouldn't ride along with this rebuild.

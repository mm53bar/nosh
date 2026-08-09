# 20260809 — No Settings model; recipe discovery is nanoclaw's job, not nosh's

## Context

Earlier the same day, [`20260809-settings-in-database.md`](20260809-settings-in-database.md)
introduced a `Setting` model with a `flaresolverr_url` field, reasoning that if nosh ever grew a
feature to scrape Cloudflare-protected recipe sites (HelloFresh, Chef's Plate), FlareSolverr access
should be an optional, operator-editable setting rather than a required env var.

On reflection, the premise doesn't hold: finding new recipes from external sites is already a
solved problem, and it's solved at the LLM/automation layer — nanoclaw's `recipe-discovery.py`
(Ollama-driven, per this household's "Claude/automation only for conversations, Ollama for
scheduled work" architecture) already does exactly this, adding finds straight into the collection
via nosh's own JSON API. There's no plan to duplicate that inside nosh itself. Without that
hypothetical feature, `Setting`/`flaresolverr_url` has no purpose at all — an empty settings page
pointing at a config value nothing reads.

## Decision

Remove the `Setting` model, the `settings` table, its controller/views/route, and the "Settings"
nav item entirely. If nosh ever grows a genuine need for operator-editable runtime config, build
the `Setting` model fresh at that point (the pattern is documented and easy to re-derive from
tsundoku's `docs/adr/20260628-settings-in-database.md`), for a value that's actually read
somewhere — not ahead of the feature that needs it.

## Consequences

- `compose.yaml` and the app have one fewer moving part.
- Any future genuinely-needed operator setting starts from a clean slate rather than inheriting a
  single-purpose `flaresolverr_url` column that never got used.

## Alternatives considered

- **Keep the `Setting` model as general-purpose infrastructure for whatever future setting shows
  up.** Rejected — this is exactly the speculative scaffolding tsundoku's own history warns
  against (see its `docs/adr/20260530-book-assets-boundary.md`-adjacent commentary and CLAUDE.md
  standing rule on this): don't keep unused scaffolding just because it might be useful later.

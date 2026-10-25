# Recipes keep the page they came from

Date: 2026-10-25

## Context

`original_text` (`20261025-ingredients-keep-their-original-line.md`) keeps an ingredient's line
from now on, but the existing 2,456 ingredients have none. The only way to recover them was to
fetch every source page again. Each time a parser or the data model changes, the same question
returns: what did the site actually say? Meanwhile pages go away. Of 173 source URLs checked on
2026-10-25, four were already 404 or 410.

At this size, keeping each page costs little. The 157 pages that still carry a recipe are 322 MB
of HTML and 58 MB gzipped.

## Decision

- **The whole page is kept, gzipped**, as the recipe's `source_page` attachment. That covers the
  JSON-LD plus anything nosh doesn't parse today: page text, image lists, a site's own app data.
- **The schema.org/Recipe node is kept as `source_data`**, so the common case of re-reading the
  ingredient lines needs no unzip-and-parse. `source_fetched_at` dates it.
- **`RecipeImporter` captures the page on every import.**
- **`POST /recipes/:id/source.json`** takes an uploaded `page`, and nosh never fetches it.
  Several sources only answer through FlareSolverr, which nosh deliberately knows nothing about
  (`20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`), so the caller sends the page it
  got. `GET` returns `source_data`.
- **Ingredient lines the JSON-LD leaves out** can come with the upload as `lines`. Chef's Plate's
  JSON-LD has an empty `recipeIngredient`; its lines exist only as page text. Reading them is
  site-specific scraping, which stays with the caller. nosh stores the caller's lines in
  `source_data` with `"nosh:ingredientLinesFrom": "page text"`, and only when the page has
  none of its own.
- **Capturing fills `original_text`** on ingredients that have none, by pairing each with a
  source line in order:
  - A **strict pass** needs the ingredient's words in the line, or the line to parse and alias to
    its name.
  - A **loose pass** then pairs what's left with a line whose parsed name is part of the
    ingredient's ("Basil" for "fresh basil").

  An ingredient no line accounts for is left blank, and nothing already set is overwritten.

## Consequences

- A future parser can be run over `source_data`, or over the stored page, and diffed against the
  live recipe without fetching anything.
- Measured against the live collection before the backfill:
  - 1,894 of 1,956 ingredients across 157 recipes paired.
  - All 45 pairs in a random sample were correct.
  - What stays blank is mostly hand edits made after import, e.g. a spice blend expanded into
    its parts.
- Recipes with no page keep nothing: 30 have no `source_url`, 10 are YouTube videos, and 4 point
  at dead pages.
- The pages live on the same Active Storage volume as the photos, about 58 MB in all.
- The stored page holds the site's numbers. Chef's Plate pages show two servings, so a source line
  can say `100 g` where the recipe says `200 g`.

## Alternatives considered

**Keep only the JSON-LD node.** Rejected: it's what nosh reads today, and the reason for keeping
anything is the parser nosh doesn't have yet. Chef's Plate proved it within the hour.

**Have nosh fetch, through FlareSolverr when needed.** Rejected for the same reason the settings
model was: it puts scraping infrastructure into nosh for a job that belongs to the automation
layer.

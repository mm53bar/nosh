# Ingredients keep the line they were created from

Date: 2026-10-25

## Context

An ingredient's line is reshaped as it arrives: split into name and note, its amount parsed into
a number, its name possibly aliased. When the amount migration changed how amounts were stored,
the only record of what the sources had written was a JSON export taken just beforehand
(`recipes-before-amount-migration-2026-10-25.json`, outside this repo). Any future parser change
has the same problem.

Tandoor Recipes keeps `original_text` on every ingredient and never lets it be edited.

## Decision

`ingredients.original_text` holds the line the ingredient was created from.

- `RecipeImporter` sets it to the `recipeIngredient` string, exactly as scraped.
- Any other create builds it from what the caller sent, before any splitting or aliasing:
  amount as written, unit and name, then `, note`. A caller that has the raw line can send
  `original_text` itself.
- It is written once. `original_text=` is ignored on a persisted record, so an update carrying it
  (the JSON API, the edit form) changes nothing and doesn't fail.
- The JSON API returns it on every ingredient.

## Consequences

- A parser change can be re-run against `original_text`, and its effect diffed, with no export.
- Rows created before 2026-10-25 have none. No faithful source exists to backfill them: the
  migrated names had already been through two cleanups.
- It is never shown in the UI.

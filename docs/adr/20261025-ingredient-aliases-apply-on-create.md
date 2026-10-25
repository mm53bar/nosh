# Ingredient aliases apply on create

Date: 2026-10-25

## Context

The ingredient audit (in the operator workspace, outside this repo) settles which names are the
same thing to buy and renames them. Its renames fixed the rows that existed. The next import from
a site that writes "scallions" brought the old name straight back, so every audit run re-found
fragmentation it had already ruled on. Applying a rename also meant PATCHing each affected recipe
one at a time.

Tandoor Recipes solves this with automation rules applied as an ingredient is parsed (its
`FOOD_ALIAS`), plus a merge endpoint that re-points every reference at once.

## Decision

`IngredientAlias` maps a `variant` to a `canonical` name.

- **Recording an alias renames** every existing ingredient whose name is the variant, ignoring
  case and spacing, and reports how many.
- **`Ingredient` applies it on create**, after splitting the line into name and note. Like the
  split, it never runs on update: an update is someone deciding.
- **Exact names only.** Which near-misses are one product is the audit's judgment (fresh vs
  ground ginger, toasted vs plain sesame oil). A fuzzy matcher here would make those calls
  silently.
- **One hop deep.** A canonical that is itself a variant resolves to its own canonical, and
  aliases pointing at a new variant follow it. An alias that would undo another is refused.
- **An alias may name its own variant** to settle casing: `salt → salt` renames every "Salt"
  and "SALT" to "salt". Imports title-case freely, and the audit's casing merges need this.
- **`POST /ingredient_aliases.json`** with `{ingredient_alias: {variant, canonical}}`. Posting a
  variant that already exists re-points it, so the audit can send its whole decision log every
  run. `GET` lists them, `DELETE` removes one, which renames nothing back.

## Consequences

- Imports, nanoclaw's recipe-discovery writes and the edit form all land on the settled name.
- Aliases are separate from `Staple#aliases`. Those resolve what someone said to a tab; these
  resolve what a recipe calls an ingredient. An ingredient alias can make a recipe line match a
  tab it previously missed.
- Removing an alias stops future renames only.

## Alternatives considered

**Apply the audit's normalised base-name rules inside nosh.** Rejected: those rules strip
preparation words that sometimes name a different product, which is why the audit keeps
case-by-case decisions. Exact aliases only ever repeat a decision already made.

**Keep renaming through `PATCH /recipes/:id`.** Rejected: it fixes the past and not the future.

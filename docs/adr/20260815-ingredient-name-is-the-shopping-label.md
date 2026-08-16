# Ingredient `name` is the shopping label; everything else goes in `note`

Date: 2026-08-15

## Context

`ingredients` had four columns — `amount`, `unit`, `name`, `position` — and `name` was doing
three jobs at once: naming the thing you buy, describing how to prepare it, and carrying asides
the source page happened to include.

That happened structurally, not by accident. `RecipeImporter` reads schema.org's
`recipeIngredient`, which is a single freeform string per line (`"1 (14 ounce) package
extra-firm tofu, drained"`). The old parser captured a leading quantity and an optional unit,
then swept the entire remainder into `name` with a greedy `(.+)`. There was nowhere else for the
remainder to go.

Measured across the 133 migrated recipes (583 distinct ingredient names):

| | share |
|---|---|
| longer than 30 characters | 30% |
| contain parentheses | 21% |
| contain a comma or " and " | 15% |
| have a quantity inside `name` | 10% |

The longest was 176 characters. This was tolerable while `name` was only ever read on a recipe
page next to its own amount. It stopped being tolerable once the shopping list became something
read at a glance in a grocery aisle and spoken aloud by a voice assistant, where a 176-character
name is unusable.

The two readers want opposite things. A cook wants "drained", "rubbed not ground", "or
vermouth". A shopper wants "tofu". One column cannot serve both.

## Decision

Add `ingredients.note`, and define `name` as **the shopping label** — the words needed to buy the
thing, nothing more. Package sizes, preparation instructions, substitutions and warnings live in
`note`, which renders after the name on the recipe and kitchen pages and is ignored by anything
building a shopping list.

Parsing moves out of `RecipeImporter` into `IngredientLine`, which the importer and any backfill
both call, so a name imported today and a name repaired tomorrow are shaped by the same rules.

`IngredientLine` only moves what is **structurally unambiguous**:

- a parenthetical, wherever it appears
- a trailing clause that *begins* with a known preparation word

Everything else stays in `name` untouched. Substitutions ("white wine or vermouth") and lines
covering several ingredients at once are left exactly as found.

`IngredientNameLinter` reports names that still look wrong. It is a reporter, never an editor,
and deliberately **not** a model validation: a validation would reject legitimate imports and
start failing nanoclaw's recipe-discovery writes, turning a data-quality signal into an outage.
Run it with `bin/rails ingredients:lint`. It is not part of `bin/ci`, which runs against fixtures
where there is nothing to find.

## Consequences

- The shopping list can use `name` verbatim. No string surgery at display or export time, in
  nosh or in anything consuming its API.
- Cooking information is preserved rather than trimmed away. This is the point of the note
  column, and the reason a plain "shorten the names" pass was rejected.
- Existing rows need a backfill, which is a separate exercise: of 583 names, roughly 138 are
  mechanically reducible and roughly 81 need a human decision.
- New sources of untidy names — a site with unusual `recipeIngredient` formatting, a recipe added
  over the API — will keep appearing. The linter is how they surface, rather than by someone
  noticing a bad shopping list.
- Two writers now have to agree on this contract: `RecipeImporter`, and nanoclaw's
  `recipe-discovery.py`, which POSTs ingredients directly.

## Alternatives considered

**Reduce names at shopping-list build time.** Rejected: it leaves the bad data in place, so the
recipe pages stay unreadable and every future consumer has to re-implement the same reduction.
The problem is in the data, not the display.

**Shorten `name` and discard the rest.** Rejected: the collection contains real substitution
options and at least one allergen warning ("check label for shrimp/fish") living inside an
ingredient name. A hand review of this same data in August 2026 explicitly refused to delete
those. A `note` column is what makes the reduction safe — the text moves instead of dying.

**Make the parser smarter about substitutions and multi-ingredient lines.** Rejected for now.
Those need judgment about what the household actually buys, and a wrong guess is silent. Left to
the linter and a human, with an audit-style decision log so the same name is only ruled on once.

**Enforce the shape with a model validation.** Rejected — see above; it would break the API
writers nosh does not control.

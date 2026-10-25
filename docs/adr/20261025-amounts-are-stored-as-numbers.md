# Amounts are stored as numbers and formatted on display

Date: 2026-10-25

## Context

`ingredients.amount` and `shopping_list_items.amount` were strings holding whatever the source
wrote. Across the 203 live recipes (2,456 ingredients) the same quantity appeared as `1.5`,
`1 1/2`, `1½`, `1 ½` and `3-1/2`-style hyphenated mixed numbers, alongside ranges (`2-3`,
`2–3`, `1/4–1/2`) and a handful of words (`to taste`, `handful`, `squeeze`).

Two problems followed from that:

- **Display depended on the source.** A recipe could show `1.5 cups` next to `½ cup`, and an
  importer bug could store `1 and 1/2` as amount `1` with `and 1/2 cups` in the name.
- **The shopping list could not add up.** `ShoppingListBuilder` only summed amounts that
  `Float()` accepted, so `1 1/2` and `½` were concatenated as text instead of totalled, and
  totals it did compute were rounded to one decimal (`1.5`, `0.3`).

## Decision

Store amounts as numbers and turn them into text only at the edges, the way times are stored
in UTC and shown in a zone.

- `amount` is `decimal(12, 4)`. A range adds `amount_max`; a single amount leaves it nil.
- **On the way in**, `HasAmount#amount=` accepts a number or any written form and parses it
  with `IngredientAmount.parse`. API callers, the edit form and `IngredientLine` keep sending
  text. Text with no number in it is never written to the column, because a decimal column
  casts `to taste` to `0`; on an ingredient it moves to the front of `note`.
- **On the way out**, `IngredientAmount.format` renders a number with Unicode fraction
  characters (`1½`, `⅔`, `2–3`). Every view and the Home Assistant push use it.
- The JSON API returns `amount` and `amount_max` as numbers plus a formatted `quantity`
  string, so a reader that wants text does not have to format it.
- The shopping list sums the numbers, scaled by servings, and adds ranges as ranges.

## Consequences

- **Thirds are not exact.** `1/3` stores as `0.3333`. `format` snaps to the nearest half,
  third, quarter, sixth or eighth within 0.01, so `0.3333`, three of them summed (`0.9999`)
  and HelloFresh's float noise (`0.66666668653488`) all display correctly. A decimal that
  is not near a kitchen measure (`0.3`, `0.06`) displays as a decimal.
- **Fifths are not snapped**, because a decimal like `0.4` is more often metric than
  two-fifths. A written `⅖` still parses.
- **The edit form shows the formatted value** (`1½`) and parses it back on save.
- **Reading the API changed type.** `amount` was a string and is now a number. nanoclaw's
  writers already send text, which still parses.

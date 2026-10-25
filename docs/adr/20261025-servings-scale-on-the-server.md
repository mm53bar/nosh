# Servings scale on the server, through a Turbo Frame

Date: 2026-10-25

## Context

Amounts became numbers the same day (`20261025-amounts-are-stored-as-numbers.md`), which made
scaling a recipe arithmetic rather than string surgery. The shopping list already scaled by a
meal-plan entry's servings; neither recipe page could. Cooking for six from a recipe written for
four meant doing the sums at the counter.

## Decision

- `?servings=N` on either recipe page (`/recipes/:id`, `/kitchen/recipes/:id`) shows every
  quantity multiplied by `N / recipe.servings`. `Recipe#servings_for` keeps `N` to 1–48 and
  ignores anything that isn't a number. A recipe with no `servings` can't be scaled and shows
  no control.
- The scaled number is formatted by `IngredientAmount.format`, the same as every other amount.
  `display_amount` and `quantity` take an optional scale; nothing else formats.
- The control is − / + links inside a `turbo_frame_tag "ingredients"`. A tap re-renders only the
  ingredient list and replaces the URL, so the method's step progress survives it and a reload
  keeps the count.
- A meal-plan card on the kitchen screen opens its recipe at the planned servings when they differ
  from the recipe's own.

## Consequences

- One round trip per tap. Measured on the LAN this is a few milliseconds of server time.
- Scaling can produce amounts like `262½ g`: the formatter snaps to kitchen fractions whatever
  the unit. Rounding metric weights is a formatter change, not a scaling one.
- On the kitchen screen the stepper is its own row under the heading. Inside the 853×533 frame
  the row measures 224.5px in a 224.5px column, with 8.4px to spare after the + button. Re-measure
  before widening it.
- The JSON API is not scaled.

## Alternatives considered

**Scale in the browser with a Stimulus controller.** Rejected: it needs the fraction snapping and
glyphs reimplemented in JavaScript, and two formatters drift.

**A free-text servings field.** Rejected for the kitchen screen, where typing is the thing a
floury hand can't do.

# 20260809 — Equipment and Technique as their own models

## Context

The recipe list's "Type" sidebar facet was showing values like "Sauce" and "Technique" alongside
real meal categories (Dinner, Breakfast, Snack) — because `meal_type` was being used as a catch-all
for "what kind of thing is this" rather than strictly "when do you eat it." Digging into why
surfaced two related but distinct problems:

1. Some recipes (marinara, pizza dough, a soft-boiled-egg method) are really *components* used
   inside other dishes, not meals in their own right — they'd been jammed into `meal_type` for
   lack of anywhere better to put them.
2. Free-text tags already included equipment references (`pasta maker`, `air fryer`,
   `food processor`, `instant-pot`) mixed in with cuisines, dietary flags, and source attribution
   — another "no dedicated spot, so it went in the closest available bucket" symptom.
3. Separately, there's a real want for genuine technique/reference content that isn't shaped like
   a recipe at all — e.g. "how to get cast iron non-stick" (no ingredients, just a method) or "the
   ratio for a basic vinaigrette" (a formula, not a discrete dish). Surveying other self-hosted
   recipe managers (Mealie, Tandoor) found Mealie has a proven `Tools`/equipment concept, but
   neither treats technique/reference content as a first-class type — that pattern looks specific
   to recipe *blogs* (e.g. cookingforengineers.com), not recipe *managers*. Since no comparable app
   validates the idea, the decision here rests on this household's stated, concrete need rather
   than "everyone else does this."

## Decision

Two new models, both following the existing `Tag`/`RecipeTag` pattern:

- **`Equipment`**: `name` + `owned` boolean. Many-to-many with both `Recipe` and `Technique`.
  Seeded from the household's actual kitchen list (`db/seeds.rb`) so the sidebar facet and edit
  forms have real options from day one. Gets the same create-on-the-fly-by-name treatment as tags
  (`HasEquipment` concern, shared by `Recipe` and `Technique`) — a piece of equipment is just a
  name, safe to create from a text field.
- **`Technique`**: `title` + `body` (freeform instructions/tips). Many-to-many with `Equipment`
  (a technique can reference the tool it's about) and with `Recipe` (a recipe can point at a
  related technique — "see: basic vinaigrette ratio"). Full CRUD, listed in nav. Unlike equipment,
  linking a *recipe* to a technique only offers existing techniques (`technique_ids`, the writer
  Rails already generates for a `has_many :through`) — no create-on-the-fly, because a technique
  needs real authored content to be worth anything; a stray text-field typo shouldn't silently
  create an empty stub.

The 9 mis-categorized recipes and the 4 equipment-shaped tags are a one-time data cleanup
(`~/projects/recipes/reference-scripts/reclassify-equipment-and-techniques-2026-08-09.rb`), not a
schema change — `meal_type` cleared and replaced with a proper tag (`sauce`/`dough`/`technique`)
for the former, tags reclaimed into real `Equipment` associations for the latter.

## Consequences

- The "Type" sidebar facet only shows real meal categories again.
- Equipment tracking doubles as a "what do we actually own" reference, not just a recipe filter.
- Technique content has a real home, separate from the Recipe shape (no forced ingredients/steps
  for content that doesn't have them).

## Alternatives considered

- **A single `is_component` boolean on Recipe instead of new models.** Rejected once the
  Technique need (content with no ingredients at all) became clear — a boolean can't hold "how to
  season cast iron," and the equipment tag-reclaiming problem is independent of it anyway.
- **Model technique content as a special Recipe (empty ingredients).** Rejected — forcing
  prose/reference content through the Recipe shape (title + ingredients + steps + servings +
  rating) means carrying a lot of irrelevant fields for something that isn't a dish.

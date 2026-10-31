# 20261030 — The week's dinner ideas live on the Meal Plan page

## Context

Every Saturday a nanoclaw script asked an LLM for eight dinners from nosh's collection and
posted them to Slack. Someone replied with picks, and a Claude agent in Slack turned the reply
into meal-plan entries and published the shopping list. The script told the model the household
was "mostly vegetarian", which is wrong, and nights without a recipe ("burrito night") could
not be planned at all.

The household wants to mix the week's ideas with other recipes, night by night. Publishing the
shopping list in the same click as planning would take that away.

## Decision

- **`DinnerSlate`** holds a week's ideas: recipe ids, each with a complexity and a one-line
  reason. `DinnerSlateJob` makes next week's on Saturday at 8am.
- **Ruby decides what may be suggested; the model only chooses.** The pool leaves out:
  - anything cooked in the last 14 days, or planned in that time or for the week itself;
  - anything whose meal type isn't blank, dinner or a main.

  Ids the model names outside the pool are dropped. If fewer than half the ideas survive (one
  retry), the slate is kept as failed, so the banner says so rather than showing an empty week.
- **The prompt in the repo is generic.** The household's own likes and dislikes are
  `Setting#dinner_slate_notes`, edited in a box under the ideas, because the repo is public. See
  `20261031-household-settings-in-the-database.md`.
- **Picking happens on the Meal Plan page.** The ideas sit above the week. Each idea has an
  "Add to…" menu of that week's nights, and each night's dropdown lists the ideas first, then
  every recipe. An idea already on the plan shows which night.
- **"Suggest again"** makes a new slate for the same week. It keeps the ideas already on the plan
  and never repeats the others. It runs in `DinnerSlateJob`, not the request, because a model
  call can outlast Thruster's 30-second write timeout. The page refreshes itself over Turbo
  when the job finishes. A failed retry doesn't replace anything: the slate showing keeps its
  ideas and gets an `error` line explaining why.
- **Shopping stays its own step.** "Shopping list for this week" opens the Shopping page with
  that week's dates in "Build from meal plan".
- **The banner** under the header says when a week's ideas are ready, until someone opens that
  week. It says when they couldn't be made until a slate works or the week ends.
- **A night can be just a name.** `MealPlanEntry` takes a `title` when it has no recipe. It shows
  on the plan and the kitchen screen, and adds nothing to the shopping list.

## Consequences

- nanoclaw's `meal-plan.timer` and Casey's "finalising the plan" instructions can go.
- `/meal_plan_entries.json` can return `recipe_id: null`. `title` is always the night's name.
- One model call a week, plus one per "Suggest again".

## Alternatives considered

- **Plan and publish in one click.** Rejected: the household wants to change nights after
  choosing ideas, and the shopping list is the board's business.
- **A separate slate page with checkboxes**, feeding an unscheduled tray. It adds a page and a
  step, and an entry with no date.
- **A Slack post or a Home Assistant notification.** Not chosen for now. The banner needs no new
  integration, and either can be added if the banner isn't enough.
- **Filtering meat by an ingredient word list**, as recipe review does. On the live collection it
  flags miso broth and "no-chicken" base as meat. The collection is meant to be vegetarian, so a
  meat recipe in it is a data problem to fix in the recipe.

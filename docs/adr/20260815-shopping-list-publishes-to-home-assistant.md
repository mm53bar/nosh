# The shopping list publishes to Home Assistant instead of being read in nosh

Date: 2026-08-15

## Context

nosh builds a shopping list by aggregating a week's meal plan, and until now that list was only
readable in nosh. The household's actual shopping list had moved to Home Assistant, where it is
reachable three ways nosh cannot match: by voice, on the kitchen screen as a tappable list you
check off while unpacking, and on a phone in the store.

Two lists, one of them stale, is worse than either alone.

Home Assistant's `todo` domain has no category field — `TodoItem` is exactly
uid/summary/status/due/description/completed. The household's HA install works around this by
encoding a store aisle index into `due` as a date in 2099, sorting the card by due date and
hiding the date with `card_mod`. An automation there stamps every newly added item by keyword,
whoever added it.

That last part decides the split of work. HA already categorises voice- and phone-added items
that nosh never sees. If nosh categorised too, there would be two maps to keep in agreement and
nosh's would cover the smaller share.

## Decision

nosh pushes items and nothing else. `ShoppingListPublisher` reads the target list, diffs
case-insensitively, and adds what is missing:

- `summary` is the ingredient name alone, because it is read at a glance in an aisle and spoken
  by the voice readback.
- `description` carries quantity and source recipe — "200 g · Tofu Noodles" — answering why an
  item is on the list. `ShoppingListItem#source` was added to make this possible.
- Categories, sort keys and ordering are Home Assistant's business. nosh sends neither.

**Additive, and it removes only what has been bought.** Publishing first calls
`todo.remove_completed_items`, then diffs, then adds. Outstanding items — whoever added them —
are never touched, and the list is never bulk-replaced.

Clearing bought items is not tidiness. The diff treats anything already present as handled, so a
staple bought last week and left sitting `completed` would silently suppress this week's genuine
need for it. Taking bought items out first makes "already on the list" mean "still outstanding",
which is the only reading that stays true week to week.

The limit worth knowing: this does **not** make re-publishing the same plan idempotent. Anything
bought since the last publish is cleared and re-added. Publish once per plan; a second run after
a shop would re-add the whole trip. Discovered the hard way on 2026-08-16, when a re-publish
would have added 55 items that had all just been bought.

**No bulk replace, no removing outstanding items.** That list is live household
state with several writers, and `ShoppingListBuilder`'s `delete_all`-then-rebuild is safe
precisely because it only ever touches nosh's own table. The worst a publish can do is leave a
stale item behind, which beats deleting something a person put there by voice.

`POST /shopping_list/publish` is the one entry point, for both callers: a "lock it in" button in
nosh, and the LLM automation finalising a week from Slack. Given a date range it rebuilds the
list first. The push runs as `ShoppingListPushJob` because it is one HTTP call per item.
`GET /shopping_list/publish_preview` reports what would be added without writing.

Everything install-specific is env — `HA_BASE_URL`, `HA_TOKEN`, `HA_TODO_ENTITY` — because this
repo is public. Unset, nosh behaves exactly as before.

One behaviour is detected at runtime rather than configured: **descriptions**. The legacy
`shopping_list` integration reports `supported_features: 15` and answers a description with HTTP
500 rather than ignoring it. nosh checks bit 64 and folds the quantity into the name when it is
missing.

nosh sends items and nothing else. An earlier draft had it fire an installation-specific event
after each batch, to nudge a categorising automation that could miss an item added in a narrow
window. That was the wrong place to fix it — the timing constant lives in the Home Assistant
package, so a public repo would have been coupled to a private detail it cannot see. The debounce
belongs on the automation, and now lives there.

## Consequences

- The list is only as well sorted as HA's keyword map. Measured against nosh's 569 distinct
  ingredient names, the expanded map places 98%; the rest land in an "Other" bucket at the end.
  Growing it is HA-side work.
- Removing an item from the meal plan does not remove it from the shopping list. Deliberate for
  now — see Alternatives.
- nosh's own `ShoppingListItem#category` and the bulk-category endpoint are no longer on the path
  to anything. Left in place because nosh's list page still groups by category; worth revisiting
  once the HA list is the only one anyone reads.
- The LLM automation's weekly "categorise the shopping list" step becomes redundant.
- nosh now has an outbound dependency that can be down. It fails as a background job with retries
  and never blocks a request; the next publish re-diffs and picks up whatever didn't land.

## Alternatives considered

**A custom Home Assistant integration, making nosh's list the entity itself.** Rejected for now.
It is the cleaner data model — no diffing, no duplicate bookkeeping — but HA deliberately exposes
exactly one `todo` entity, because several make "add X to the shopping list" an ambiguous voice
match, so a nosh entity would have to *replace* `local_todo` rather than sit beside it. That
makes nosh a hard dependency for a daily voice feature, puts freeform voice items ("Advil") into
`shopping_list_items` where `ShoppingListBuilder` would delete them on the next generate, and
adds a third repo in Python on HA's release cadence. Revisit if the push proves the shape.

**Removing items when the plan changes.** Rejected for v1. Correct removal needs to know which
items nosh added and that nobody has touched them since; matching on name risks deleting
something a person added independently.

**Categorising in nosh and sending a sort key.** Rejected: it duplicates a map HA already has and
applies to fewer items — see Context.

**Pushing on meal-plan creation.** Rejected: entries are created one at a time, so there is no
moment at which the plan is known to be complete. Publishing needs an explicit signal.

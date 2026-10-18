# The shopping list is a staples board, owned by nosh

Date: 2026-10-18

Supersedes `20260815-shopping-list-publishes-to-home-assistant.md`.

## Context

The shopping list has lived in a Home Assistant `todo` list since August, with nosh pushing a
week's ingredients into it. That was chosen because Home Assistant could reach places nosh
could not: voice, the kitchen screen, and a phone in the store. Everyone who shops can now reach
the household network from a phone, so the last of those reasons is gone, and the list's
failures are all of the freeform-list kind:

- **Duplicates.** A `todo` add never deduplicates. The live list held "cornstarch" nine times,
  each added by voice.
- **Silent mishearings.** Speech-to-text turns a request into a *plausible* sentence. "Add
  oatmeal" carries no error signal, so whatever was misheard is added faithfully.
- **Categories by workaround.** `TodoItem` has no category field, so Home Assistant encodes an
  aisle into a due date in 2099 and keyword-matches every item to stamp it.
- **Staples overbought.** A recipe that uses butter put butter on the list every week, whether
  or not the fridge had any.

Of the 53 voice- or phone-added items on the live list, nearly all were the same small set of
pantry and fridge staples, added again and again. That is the shape of a 1950s pocket shopping
list: a fixed card of staples with a tab beside each one, flipped when it runs out.

## Decision

nosh owns the whole shopping list. It has three parts, and each answers a different question.

**The board — "what are we out of?"** A fixed set of `Staple`s grouped by `Aisle`, each with a
`needed` flag. A tab is flipped on by a person who has looked in the cupboard, and flipped off
when it is bought. Flipping is idempotent, so two people asking for milk produce one milk.

**Write-ins — "what else, just this trip?"** Anything typed into nosh that is not a staple
becomes a `WriteIn`, shown at the bottom of the board like the blank lines on the old cards,
and gone once bought. When the same name has been written in three times, nosh offers to make it
a tab. Nobody is asked "keep this?" while typing, because that asks for a prediction and gets the
costly answer wrong: a wrong write-in disappears, a wrong tab stays forever.

**This week — "what do the planned meals need?"** `ShoppingListBuilder` still aggregates the
meal plan, but an ingredient that matches a staple **does not flip its tab**. It is shown as a
marker on the tab instead — quantity and recipe — and kept out of the "this week" lines. A tab
means *we are out*, which only a person knows; a recipe using butter is a guess. If the plan
could flip tabs, nobody in the store could tell the two apart, and the board would stop being
trusted. Ingredients that are not staples are the "this week" lines, with quantities, as before.

**One matcher for every way in.** `StapleMatcher` resolves what someone said or typed to a
staple, by name or alias, ignoring case, articles and a plural. It answers one of three ways:

- a **staple** — flip it;
- a **group** — the input named a group of tabs ("cheese", "oil") rather than one of them. Every
  staple in a group is something different to buy, so the group word on its own never flips
  anything; the answer is the list of tabs to choose from;
- **unknown** — with the closest tab, if one is close.

**Voice can only flip tabs.** It never creates a write-in or a tab. An unknown item is refused,
and the reply says where it can be added instead and names the closest tab, so a mishearing is
heard and can be corrected by saying the right word. nosh writes the spoken reply itself
(`speech` in the JSON response), so the voice layer stays a thin pass-through and the wording
lives next to the logic it describes. Several items in one request ("butter and eggs") are split
by nosh, after trying the whole phrase as one name first so a staple containing "and" still
matches.

**The voice layer is Home Assistant's, and it is thin.** A sentence and an intent script post the
spoken item to nosh and speak the `speech` field back. No `todo` entity, no custom integration.
The kitchen screen frames nosh's board the way it already frames `/kitchen`, so its writes are
JSON requests, per `20260812-framed-by-home-assistant.md`.

The board's contents are household data, so they are not in `db/seeds.rb` in this public repo.
They are created through the JSON API like any other record.

## Consequences

- The kitchen screen, phones and voice all depend on nosh being up. A request made while it is
  down fails out loud on every path; nothing is queued or dropped silently.
- **Transition.** The Home Assistant push (`ShoppingListPublisher`, `HomeAssistantTodo`,
  `ShoppingListPushJob`) stays in place until Home Assistant has switched over, so the household
  list keeps working while the board is built. It is removed at cutover, along with the
  `HA_*` env and the `category` column, which nothing reads once the board groups by aisle.
- Aisle order is data. Re-ordering for a real store walk is an update to `aisles.position`.
- Matching is by name and alias, so the plan's markers are only as good as ingredient names. An
  ingredient that names no single product ("shredded cheese") cannot mark a tab and appears as a
  "this week" line. That is a recipe-data fix, the ingredient-audit's job, not the matcher's.
- Quantities on staples are gone: a tab is on or off. Quantities survive on "this week" lines and
  on plan markers, where they come from a recipe and mean something.

## Alternatives considered

**A custom Home Assistant integration exposing nosh's list as a `todo` entity.** Considered
again for this change. It keeps Home Assistant's stock voice intents and cards for free, but it
also keeps every freeform-list failure above, because the `todo` model *is* a freeform list. It
also needs a third repository, in Python, on Home Assistant's release cadence.

**Recipes flip staple tabs.** Rejected: see "this week" above. It makes overbuying automatic and
destroys the one fact the board holds.

**Voice adds unknown items as write-ins.** Rejected: it reopens the silent-mishearing hole, which
is the main thing a fixed vocabulary closes.

**Ask "keep on the board?" when typing an item.** Rejected in favour of offering a tab on the
third write-in: history makes that prediction better than a person in a hurry does.

**Generic tabs ("cheese", "oil").** Rejected: a tab must name something that can be taken off
the shelf without asking which one. Groups give the generic word a useful answer without letting
it flip anything.

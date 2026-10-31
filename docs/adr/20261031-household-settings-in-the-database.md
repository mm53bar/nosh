# 20261031 — Household settings live in the database

Supersedes the "No Settings model" part of
[`20260809-no-settings-recipe-discovery-is-nanoclaws-job.md`](20260809-no-settings-recipe-discovery-is-nanoclaws-job.md).

## Context

That ADR removed a `Setting` model that had been built for a FlareSolverr URL nothing read, and
said to bring it back when a real value needed it. The weekly dinner ideas now need one: what
the household wants the model to know (who cooks, what they dislike, which dishes are too much
work). It is household data, so it can't go in the prompt in the repo, which is public. It
started as an env var in the deployment, but only the operator can edit that, and the people it
describes should be able to change it.

## Decision

A single-row `Setting` model, as in tsundoku (`20260628-settings-in-database.md`):
- reached through `Setting.current` (`first_or_create!`);
- named columns, not a key/value store; today only `dinner_slate_notes`;
- edited where it's used: a "What the ideas should know about us" box under the week's ideas on
  the Meal Plan page, saved with `PATCH /setting`.

There is no settings page until there are enough settings to need one. There is no env
fallback either: nothing deployed used the env var.

## Consequences

- Sheila or anyone can change the notes, and the next slate uses them.
- The notes live in the production database, so they are backed up with it and never touch the
  repo.

## Alternatives considered

- **`DINNER_SLATE_NOTES` in the compose file.** Private, but only the operator can edit it,
  and only by redeploying.
- **A settings page.** Not yet: one field belongs beside the thing it changes.

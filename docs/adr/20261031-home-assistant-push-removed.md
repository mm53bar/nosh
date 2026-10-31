# 20261031 — The Home Assistant push is removed

## Context

The staples board (`20261018-shopping-list-is-a-staples-board.md`) kept the old push into a Home
Assistant to-do list until HA cut over. HA did that on 2026-10-30:
- `todo.shopping_list` is deleted, along with HA's category and aisle package;
- voice calls nosh's `POST /staples/need` and `/staples/have` and `GET /shopping_list.json`;
- both kitchen kiosks frame nosh.

Nothing in HA reads a to-do list any more, so every push would fail.

## Decision

nosh no longer writes to Home Assistant. Removed:
- `ShoppingListPublisher`, `HomeAssistantTodo` and `ShoppingListPushJob`;
- `POST /shopping_list/publish` and `GET /shopping_list/publish_preview`;
- `PATCH /shopping_list_items/bulk_update` and the `category` column on `shopping_list_items`,
  which existed only to feed HA's aisle sorting;
- the `HA_BASE_URL` / `HA_TOKEN` / `HA_TODO_ENTITY` env.

"Build from meal plan" (`POST /shopping_list/generate`) still fills the board's "This week"
lines from the plan.

## Consequences

- A caller still posting to `/shopping_list/publish` gets a 404 rather than a silent push to
  nowhere. Casey's instructions on nanoclaw named that endpoint.
- HA can retire its `nosh` user once the token is gone from nosh's deployment.
- Don't add a write to HA back. The board is the only list. HA speaks the `speech` string nosh
  returns, so that contract can't change without telling the `homeassistant` side.

## Alternatives considered

- **Keep the push, unconfigured.** That leaves dead code and an endpoint that looks like it
  works.

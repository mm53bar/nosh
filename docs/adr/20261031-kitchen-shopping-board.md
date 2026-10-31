# 20261031 — The kitchen shopping board is one screen of tabs

## Context

Home Assistant cut over to nosh's staples board on 2026-10-30. As a stopgap, both Echo Show
kiosks framed the full `/shopping_list?embed=1`. That page ignores `embed=1`, so HA's back button
covers the nosh logo. It is also laid out for phones and laptops, so most of the board is below
the fold of the 853×533 frame (`20260817-kitchen-embed-reserves-the-corner.md`).

## Decision

`/kitchen/shopping_list` is the board at counter distance:
- **All the tabs on one screen,** one row per aisle: the aisle name in a 72px gutter, its tabs
  wrapping across the rest. Tap a tab to flip "we're out", through the same JSON `PATCH` as the
  full page.
- **Write-ins** in a last row, tapped to tick off.
- **A dot** on a tab the week's meals use. The "this week" lines themselves are left off; they
  are for the store, not the kitchen.
- **No typing.** Voice adds, and the kiosk keyboard is slow.
- **The corner rule holds:** `kitchen_corner_reserve` on the header, as on every kitchen screen.

## Measured (2026-10-31)

Measured inside an 853×533 iframe, `?embed=1`, with the 56-tab household board, 3 tabs needed,
and 3 write-ins (one of them 34 characters long):
- The header is 0–74px and the title starts at x=74. No tab sits inside the 74×74 corner.
- Tabs are 30px tall, and the narrowest is 39.6px wide.
- The lowest tab ends at y=502.4, so **30.6px clear of the fold** with nothing scrolling.
- Produce and Baking & Spices each fit on one row with about 16px to spare (725 and 729 of
  741px). One more tab in either wraps it to a second row, which costs about 36px. That still
  fits with no write-ins, but not with three. The panes scroll rather than clip, so an
  overfull board degrades to a short scroll.

Re-measure before growing a tab or adding a row.

## Consequences

- HA's kiosk Shopping view should frame `/kitchen/shopping_list?embed=1` instead of
  `/shopping_list?embed=1`. That change belongs to the `homeassistant` side, in
  `echo-show/panel/build_panel.py` → `shopping_view()`.
- `board_controller.js` serves both pages. The add box is optional (`hasAddTarget`).

## Alternatives considered

- **Four columns of aisles.** It overflowed by 74px: column balancing can't even out an aisle
  of 14 tabs against one of 2.
- **Making `/shopping_list` honour `embed=1`.** That page's type scale, add box and "this week"
  section are right for a phone and wrong for the counter, the same reason the kitchen
  recipe screen is separate.

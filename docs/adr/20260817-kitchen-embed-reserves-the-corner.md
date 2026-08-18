# 20260817 — `?embed=1` reserves the kitchen screen's top-left corner

## Context

The Home Assistant dashboard that frames `/kitchen` (see
`20260812-framed-by-home-assistant.md`) has moved from a full-screen view to cards and panels.
A panel needs a way to dismiss it, and on the Echo Show there is no browser chrome to do that
with — so Home Assistant floats its own close button over the top-left corner of the frame:
a 46px circle, inset 14px, wanting 14px of clearance.

That button belongs to Home Assistant. It closes the panel, which is a thing nosh has no way to
do from inside an iframe, and it has to be drawn by the parent because it must sit above nosh's
content. What nosh owes it is empty pixels: a 14 + 46 + 14 = **74px square** in the corner with
nothing tappable underneath. Today both kitchen screens put something there — the meals heading,
and the recipe screen's own back button.

nosh can't detect this on its own. `window.top` is cross-origin, and the same screen is opened
directly in a browser often enough (that's how it's developed) that always leaving the corner
blank would just look like a layout bug.

## Decision

`?embed=1` on any `/kitchen` URL means "a close button is being drawn over your corner". When
it's set, the topmost element on the screen takes 74px of leading padding instead of its usual
`ps-6` / `ps-8`; when it isn't — including for any falsey or absent value — nothing changes.

The geometry lives in one place, `KitchenHelper::EMBED_CORNER_PADDING`, applied through
`kitchen_lead_padding`, so both screens (and any future one) reserve the same square. It's spelled
as a literal `ps-[74px]` rather than computed from the three numbers, because Tailwind only
compiles an arbitrary value it can read literally in the source.

Padding, not an absolute overlay, because it has to actually displace content: a spacer that
content could flow under would leave the heading unreadable and the back button unreachable
beneath a button that isn't nosh's.

`Kitchen::BaseController` adds the param to `default_url_options` next to `?theme=`, for the same
reason — there's no address bar on the kiosk to re-enter it with, so a param set once on the
embedded URL has to survive every tap.

The recipe screen keeps its own back button, moved clear of the reserved square. Home Assistant's
corner button closes the panel; stepping back to the week is a different action, and the kiosk has
no other way to do it.

## Consequences

- Only horizontal room is reserved. Both kitchen headers are taller than 74px (96px and ~112px),
  so the square falls entirely inside the header — a future screen whose top element is shorter
  would let the button cover content below it and would need vertical room reserved too.
- When embedded, the recipe screen shows two round-ish buttons side by side in the corner: Home
  Assistant's close circle and nosh's back arrow, 14px apart. They do different things, but if
  that reads as redundant on the wall the fix is on the Home Assistant side (don't draw a close
  button on the recipe panel), not here.
- The 74px is a contract with a value in Home Assistant's dashboard config. If the button there is
  resized, this constant and the ADR have to move with it; nothing in nosh will notice on its own.
- Verified in headless Chrome at 1280×800 by framing both screens with a 46px circle drawn at the
  documented position: nothing of nosh's renders inside the square, and content begins at exactly
  x=74 on both.

## Alternatives considered

- **Always reserve the corner.** Rejected: `/kitchen` gets opened directly in a browser during
  development and from a phone, where the gap is just a hole in the layout with nothing in it.
- **Have nosh draw the close button itself**, posting `postMessage` up to the dashboard. Rejected —
  it needs an origin to trust and a listener on the Home Assistant side, which is more coupling
  than a querystring param, and the button's look would then be nosh's problem to keep in step
  with the rest of the dashboard's chrome.
- **A generic `?inset-top-left=74` (or a CSS variable) instead of a boolean.** Rejected as
  premature: one embedder, one geometry, and a number in a URL invites a shape nobody has asked
  for. The boolean is easy to widen if a second dashboard ever wants a different corner.
- **Shifting the whole page right rather than just the header.** Rejected: it costs 74px of a
  1280px screen on every row, on a layout whose entire point is fitting ingredients and method
  on at once.

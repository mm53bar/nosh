# 20260817 — `?embed=1` reserves the kitchen screen's top-left corner

## Context

The Home Assistant dashboard that frames `/kitchen` (see
`20260812-framed-by-home-assistant.md`) has moved from a full-screen view to cards and panels.
A panel needs a way out of it, and on the Echo Show there is no browser chrome to do that with —
so Home Assistant floats its own back button over the top-left corner of the frame: a 46px circle,
inset 14px, wanting 14px of clearance.

That button belongs to Home Assistant. It leaves nosh, which is a thing nosh has no way to do from
inside an iframe, and it has to be drawn by the parent because it must sit above nosh's content.
What nosh owes it is empty pixels: a 14 + 46 + 14 = **74px square** in the corner with nothing
tappable underneath. Today both kitchen screens put something there — the meals heading, and the
recipe screen's own back button.

The recipe screen's back button is the harder half. It is *not* redundant with Home Assistant's:
theirs leaves the app, nosh's goes up one level inside it. But rendered as a bare ← in a rounded
box beside an identical-looking round ←, the two read as one control drawn twice. Nor can Home
Assistant suppress its own circle on recipe pages — the iframe is cross-origin, so the dashboard
cannot know which nosh route is showing. Both controls are on screen whether they like it or not.

nosh can't detect this on its own. `window.top` is cross-origin, and the same screen is opened
directly in a browser often enough (that's how it's developed) that always leaving the corner
blank would just look like a layout bug.

## Decision

`?embed=1` on any `/kitchen` URL means "a back button is being drawn over your corner". When it's
set, the topmost element on the screen takes 74px of leading padding instead of its usual `ps-6` /
`ps-8`, **and a 74px min-height**; when it isn't — including for any falsey or absent value —
nothing changes.

Both axes, even though only the horizontal one bites on today's two screens, whose headers are
already 96px and ~112px tall. The allowance is a square, and encoding it as one means a future
screen with a short header can't quietly slide content under the button with nothing to catch it.

The geometry lives in one place, `KitchenHelper::EMBED_CORNER_RESERVE`, applied through
`kitchen_corner_reserve`, so both screens (and any future one) reserve the same square. It's
spelled as literal `ps-[74px] min-h-[74px]` rather than computed from the three numbers, because
Tailwind only compiles an arbitrary value it can read literally in the source.

Padding, not an absolute overlay, because it has to actually displace content: a spacer that
content could flow under would leave the heading unreadable and the back button unreachable
beneath a button that isn't nosh's.

`Kitchen::BaseController` adds the param to `default_url_options` next to `?theme=`, for the same
reason — there's no address bar on the kiosk to re-enter it with, so a param set once on the
embedded URL has to survive every tap.

The recipe screen keeps its own way back, but stops spelling it as a corner button: it becomes a
labelled `‹ This week` link sitting above the recipe title, inside nosh's own heading. The two
controls are differentiated rather than deduplicated — **host chrome stays a circle in the corner,
guest navigation stays inside the guest's content** — which is what makes it obvious that they go
to different places. It's unconditional rather than embed-only: one screen to reason about, and
the label reads better than a bare glyph on a standalone kiosk too.

## Consequences

- The recipe header is ~40px taller than it was, since the way back moved from beside the title to
  above it. The two scrolling panes lose that much; at 800px they have it to give.
- Nothing may use a negative leading margin at the top of a kitchen screen — it would reach back
  into the reserved square, which padding alone can't defend. The breadcrumb pads on its trailing
  side only for this reason.
- The 74px is a contract with a value in Home Assistant's dashboard config. If the button there is
  resized, this constant and the ADR have to move with it; nothing in nosh will notice on its own.
- Verified in headless Chrome at 1280×800 by framing both screens with a mock 46px back circle at
  the documented position, light and dark: nothing of nosh's renders inside the square, content
  begins at exactly x=74, and the labelled link beside the circle reads as heading rather than as
  a second copy of it.

## Alternatives considered

- **Always reserve the corner.** Rejected: `/kitchen` gets opened directly in a browser during
  development and from a phone, where the gap is just a hole in the layout with nothing in it.
- **Have nosh draw the button itself**, posting `postMessage` up to the dashboard. Rejected — it
  needs an origin to trust and a listener on the Home Assistant side, which is more coupling than
  a querystring param, and the button's look would then be nosh's problem to keep in step with the
  rest of the dashboard's chrome.
- **Drop nosh's back button when embedded** and let Home Assistant's serve both jobs. Rejected on
  the Home Assistant side's own reading: they're two levels of navigation, not two spellings of
  one, and collapsing them would mean leaving the panel entirely to get back to the week.
- **A generic `?inset-top-left=74` (or a CSS variable) instead of a boolean.** Rejected as
  premature: one embedder, one geometry, and a number in a URL invites a shape nobody has asked
  for. The boolean is easy to widen if a second dashboard ever wants a different corner.
- **Shifting the whole page right rather than just the header.** Rejected: it costs 74px of a
  1280px screen on every row, on a layout whose entire point is fitting ingredients and method
  on at once.

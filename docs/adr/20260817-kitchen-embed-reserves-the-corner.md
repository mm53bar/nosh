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

`?embed=1` on any `/kitchen` URL means "a back button is being drawn over your corner". The rule
that follows is not *leave 74px blank* but **nothing of nosh's inside that square may need reading
or tapping**. Blank satisfies it. A photo satisfies it better, and is what the recipe screen does:
the dish at the top of the ingredients column, 281×158, with the host's circle sitting on it as a
corner overlay — the same move verso makes with its artwork. About one recipe in ten has no image;
those get a bare tinted band, 78px tall, because the button needs a surface whether or not there is
a picture for it.

For screens with no image to give — the week — the topmost element takes 74px of leading padding
instead of its usual `ps-8`, **and a 74px min-height**. When `embed` isn't set, nothing changes.

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
labelled `‹ This week` link sitting above the recipe title, the crumb the recipe hangs off. The two
controls are differentiated rather than deduplicated — **host chrome stays a circle in the corner,
guest navigation stays inside the guest's content** — which is what makes it obvious that they go
to different places. It's unconditional rather than embed-only: one screen to reason about, and the
label reads better than a bare glyph on a standalone kiosk too.

That, with the photo, gives the recipe screen **verso's shape: two columns running top to bottom,
no header band across them.** Left column — the dish, then the ingredients, scrolling under it.
Right column — crumb and title fixed, method scrolling under them. An earlier draft kept the
full-width header and shrank the photo into it at 112×88, which cost almost no layout height but
spent half the picture on the button sitting over it. At 281×158 the button is a corner overlay,
and the title, alone on its own rows, wraps to two lines instead of truncating at 46 characters.

Both kitchen headers are then cut to one row. The frame is **853×533 CSS px** — measured from the
dashboard, not the 1280×800 these screens were first drawn against — so the recipe screen's
three-line header was spending 26% of the visible height on chrome and the week's two-line header
20%. Times and servings moved to the pane headings that describe them (`INGREDIENTS · 4 servings`,
`METHOD · 20m`), and the week's date range shares a line with its title.

**"Made it" moved to the bottom of the method**, past the last step and the notes, because that is
where the cook is standing when it becomes true. It was in the header only because the header was
the fixed thing on the screen, which put *I finished* beside the recipe's name instead of after its
last instruction. The last-made label went with it and did not come back: on the screen you are
cooking from, when it was last made is a fact about some other day. Nothing else on the kitchen
screens reports it, and the JSON endpoint still returns the label for callers that want it.

Measured after: the week's header is 74px (the reserve binds). The recipe screen has no full-width
header left to measure — its title block is 125px over the method column only, and the photo above
the ingredients is 281×158, both comfortably clear of the 74px square.

And with that height back, the week goes to **four cards across, two rows deep** — 188×221 each,
bottom of row two at 527.5 of 533. All seven days are on screen at once, which is the whole point
of a screen you glance at while cooking. Header trimming alone could never have done it: the cards
had to come down ~27% either way.

## Consequences

- The corner contract now has two satisfying forms, blank or photographed. A new kitchen screen
  that has neither is the failure mode to watch for — nothing in code will catch it.
- The second row of cards clears the fold by **5.5px**. Anything that grows a card — a third meta
  item, a bigger title size, a taller image ratio — pushes the week back into scrolling. That
  number is the tripwire; re-measure rather than eyeballing it.
- Nothing may use a negative leading margin at the top of a kitchen screen — it would reach back
  into the reserved square, which padding alone can't defend. The breadcrumb pads on its trailing
  side only for this reason.
- Recipe titles no longer truncate at all: two lines of `text-2xl` over the method column holds
  every title in the collection, where the single-row header cut them at about 46 characters.
- The method column is 408px, down from 455 when a full-width header sat above both columns, and
  six of a fourteen-ingredient list show before scrolling rather than nine. Both columns were
  always going to scroll — that's what they're for — and the photo and the un-truncated title are
  what the height bought.
- "Made it" is below the fold on any recipe with more than a few steps. That's the point, but it
  does mean the one write on this screen is no longer visible on arrival — if a future screen wants
  it reachable without scrolling, that's a deliberate change, not a bug to fix in passing.
- Card photos drop from 247×139 to 188×104 and titles to two lines of `text-base`. Small, but food
  photos survive it — the picture is what makes the grid scannable, so shrinking it beat dropping
  it for a list.
- The recipe screen gained a photo it never had: 3px of pane height bought the dish appearing on
  the screen where you cook it.
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
- **verso's full-height image column** (a `figure` at 42% width, art bleeding top to bottom). Right
  structure, wrong proportion for a screen whose left column is a list you read while cooking: the
  photo is worth looking at once, the ingredients for the next forty minutes. 16:9 at the top of
  that column is the same trick at the size this screen can afford.
- **Keeping the photo as a 112×88 thumbnail in a full-width header.** Built first, and cheaper in
  layout height by about 47px of method column — but the host's button covered half of it, which
  is the thing a photo in that corner was supposed to fix.
- **A generic `?inset-top-left=74` (or a CSS variable) instead of a boolean.** Rejected as
  premature: one embedder, one geometry, and a number in a URL invites a shape nobody has asked
  for. The boolean is easy to widen if a second dashboard ever wants a different corner.
- **Shifting the whole page right rather than just the header.** Rejected: it costs 74px of the
  frame's width on every row, on a layout whose entire point is fitting ingredients and method on
  at once.
- **Letting Home Assistant reserve the strip outside the iframe**, by sizing the frame 74px shorter
  and drawing the button above it. Entirely possible and about two minutes of work on that side —
  but it spends 14% of the 534px height permanently, on every embedded view, whether or not the
  guest needs it. A safe-area contract costs nothing for a guest we control, which nosh is. The
  strip stays the right answer for a guest that can't be changed.

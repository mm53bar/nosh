# 20260821 — "Keep awake" is two backends behind one switch

## Context

The recipe screen has had a "Keep awake" switch since the browse UI was built: it holds a Screen
Wake Lock so an iPad propped on the counter doesn't sleep mid-recipe. The kitchen wall screen —
an Echo Show running Home Assistant's Kiosk Satellite app, framing nosh's `/kitchen` pages — never
got it, and needs it more. That app returns to its own dashboard after **120 s without a touch**,
and standing at a counter with your hands in the food is exactly 120 s without a touch. The cook
loses the recipe part-way through it and lands back on the kiosk's home screen.

Measured on the device by the `homeassistant` side (2026-08-20): with synthetic swipes inside the
iframe every ~21 s it never navigated away; with no touches it went home at exactly 120 s. So this
is dwell time, not an event-plumbing bug — the fix is a human-operated hold, which is the switch
nosh already has.

The switch can't simply be copied onto the kitchen template, for three separate reasons:

1. **A wake lock buys nothing there.** The kiosk app already pins the screen on
   (`screen.keep_on = true`), so the screen never sleeps. What takes the page away is the app's own
   return-home timer (120 s) and screensaver (300 s) — app-level timers no web API can reach.
2. **It wouldn't even acquire.** Screen Wake Lock is Permissions-Policy gated to `self`, and Home
   Assistant's iframe card sets no `allow` attribute, so `navigator.wakeLock.request()` rejects
   inside the frame. Confirmed here against a real cross-origin frame: `NotAllowedError`.
3. **The kiosk's own primitive is out of reach.** The app injects `window.kioskSatellite` into the
   main frame only, so nosh can't call it. The host page has to relay.

## Decision

One switch, two independent backends, and `checked` means **at least one hold is active**.

- **Wake lock** — unchanged behaviour for the iPad and any ordinary browser.
- **Host lease** — a `postMessage` contract with the page framing nosh, specified jointly with the
  `homeassistant` repo (`echo-show/EMBEDDING.md` there; the relay is that side's code, not nosh's):

  | Direction | Message |
  |---|---|
  | nosh → host | `{type:'ks-keep-awake', v:1, action:'hello'}` |
  | host → nosh | `{type:'ks-keep-awake', v:1, action:'available', renew_seconds:30, lease_seconds:90}` |
  | nosh → host | `{type:'ks-keep-awake', v:1, action:'on'}` — repeat every `renew_seconds` |
  | nosh → host | `{type:'ks-keep-awake', v:1, action:'off'}` |

Four decisions inside that are easy to get wrong, so they're written down:

**It's a lease, not a latch.** The host holds only while the newest `on` is younger than
`lease_seconds`, so a frame that dies — the kiosk destroying the view, a reload, a crash — releases
by itself and no forgotten switch can wedge the kiosk awake. `off` is a courtesy that makes release
immediate; the lease is the guarantee. Both intervals come from the `available` message, never
hardcoded here: they derive from a safety timer on the host side and can change without nosh being
redeployed.

**Renewal continues while the page is hidden.** The tempting rule — release when not visible —
is wrong, and was proposed and rejected during this work. The kiosk's return-home timer keeps
counting while its app is backgrounded, so releasing on hide means 120 s later the cook returns to
the home screen with the recipe gone: the exact bug being fixed. And the case the rule was meant
to catch doesn't exist — measured on the device, Home Assistant removes a departed view's iframe
from the DOM (deep iframe count 2 on the nosh view, 1 everywhere else), so "alive but off-screen"
doesn't happen. Frame death is what the lease bounds; visibility is not a proxy for it.

**Availability means acquirable, not present.** `"wakeLock" in navigator` is true inside the frame
while every request rejects, so a feature-detection check would show the switch and then have it
do nothing — worse than not shipping it. The controller asks for a real lock at connect and hands
it straight back. Because the spec also rejects for a hidden document, the probe only runs while
visible and re-runs on `visibilitychange` if the first attempt never got to.

**The gate is capability, not `?embed=1`.** `embed=1` means "leave the top-left corner clear" (see
`20260817-kitchen-embed-reserves-the-corner.md`) — an unrelated fact. The switch shows if the wake
lock is acquirable **or** the host acked, and hides if neither, so it's absent rather than broken
wherever it can't work. `hello` is retried a few times over ~1.2 s because nothing guarantees the
host's listener is installed before nosh loads, and the listener stays installed afterwards so a
late ack still works.

Kitchen **recipe** page only. The week's grid is a glance-and-leave screen and keeps the 120 s
behaviour. The switch is last in the Method row because the step-progress readout beside it changes
width as steps are ticked off, and a control that slides is one you mis-tap with a floury finger.

## Consequences

- **On the kiosk the switch appears a beat after the page does** — it can't be rendered until a
  backend has answered. That's the deliberate trade against a switch that lies.
- **Both templates ship the label with `hidden` on it**, and JS reveals it. So a bundle that fails
  to load leaves no switch at all instead of one that can't respond — the same "absent, not broken"
  rule the capability gate follows.
- **nosh cannot tell whether a hold is actually being honoured.** The contract has no reply to
  `on`, so a host that stops relaying looks identical to one that's working. Home Assistant mirrors
  a live hold into `input_boolean.<device>_keep_awake`, which is where to look when debugging.
- **`off` on `disconnect()` covers leaving the recipe within nosh, and nothing more.** When the
  host tears the frame out, Stimulus teardown isn't guaranteed to run. That's fine — it's why the
  lease expires. Don't try to make teardown airtight.
- **The contract spans two repos**, so it carries a `v` field and both sides ignore anything that
  doesn't match. Changing the message shape means changing the other repo in the same breath.
- **`test/harness/keep_awake_host.html` is a fake host** — a page that frames nosh and answers
  `hello`, with modes for silent and late acks and a live lease readout. It's deliberately outside
  the Minitest suite (nosh has no system-test harness — see `CLAUDE.md`): the other party to this
  contract can't be imported, so this page is the executable spec for nosh's half. Serve it over
  loopback, since `frame-ancestors` allows `http://localhost:*` and `http://127.0.0.1:*` but not a
  `file://` page's opaque origin.
- Verified against a real cross-origin frame while building this: the wake lock rejects with
  `NotAllowedError`, the switch still checks and holds on the lease alone, renewal lands on the
  host's cadence, `off` releases immediately, and a silent host leaves no switch on screen. The
  touch target is 144×48 px inside the kiosk's real 853×533 viewport.

## Alternatives considered

- **Ask Home Assistant to add `allow="screen-wake-lock"` to its iframe card.** Rejected: it would
  make the request succeed and still fix nothing, because the screen was never the problem — the
  app's return-home timer is, and no wake lock touches it. It would also make nosh's behaviour
  depend on a card attribute in another project.
- **Gate the switch on `?embed=1`.** Rejected: that param answers a different question, and using
  it here would show the switch on a framed kiosk whose host has no listener (a dead switch) while
  hiding it from anyone who opens `/kitchen/recipes/:id` in an ordinary browser, where the wake
  lock works fine.
- **A latch the host holds until told otherwise.** Rejected: any missed `off` — crash, reload, the
  host destroying the frame — leaves the kiosk permanently awake with nothing to clear it, and the
  screen where that happens is the one nobody thinks to check.
- **Release the lease when the page is hidden.** Rejected on measurement; see above.
- **Two separate controllers, one per template.** Rejected: they'd share the tricky part (what
  `checked` means when one backend fails) and drift. One controller, both templates, and the
  standalone page simply never finds a host.
- **Have nosh poll Home Assistant's REST API to suppress the timers directly.** Rejected: nosh
  already talks to HA for the shopping list, but this belongs to the *kiosk app*, not to HA's
  entity model, and it would put a household token in a page served to a kiosk browser.

# Keep awake asks for the wake lock on the tap, not at page load

Date: 2026-10-25

Amends `20260821-keep-awake-is-two-backends.md`, its "Availability means acquirable, not
present" decision. The host-lease half is unchanged.

## Context

The recipe page's "Keep awake" switch never worked in nosh, on the iPad or a laptop. The old
Express app's switch did, and it was simpler: it showed the switch whenever
`"wakeLock" in navigator`, and called `navigator.wakeLock.request("screen")` inside the
checkbox's change handler.

nosh instead probed at load. It requested a real lock with no user gesture, released it,
and revealed the switch only if that worked. The probe exists for a real reason: inside the
kitchen kiosk's iframe the API is present but every request is refused by Permissions-Policy.
On an ordinary page, though, the probe is the most likely thing failing. A request with no user
gesture behind it is the one difference from the old app's working code, and WebKit is the
engine most likely to refuse it. If it rejects, the switch stays hidden on exactly the devices
it was built for. This was not reproduced in Safari: the fix was verified in Chrome, and on the
glass is still to do.

A second flaw rode along. When the OS released the lock on a tab switch, the switch un-checked
itself, so the code meant to take the lock back on return never ran.

## Decision

- **Unframed, presence is enough.** The switch shows when `navigator.wakeLock` exists in a
  secure context and the page is not in a frame.
- **Framed, only a host ack shows it.** That is the case the probe was guarding, and the host
  lease is the only backend that works there.
- **The lock is requested from the tap.** `change()` starts the request synchronously, before
  any `await`, so the browser counts it as user-initiated.
- **What the cook asked for is kept apart from what is held.** An OS release leaves the switch
  on, and the lock is taken back when the page is visible again. The switch turns itself off
  only when no backend holds anything.
- **The recipe page uses the Rails Blocks `switch` partial**, wrapped in the element that
  carries the controller, since the partial takes no data attributes. The kitchen page keeps its
  own larger switch, whose touch target was measured on the kiosk.

## Consequences

- A browser that has the API but refuses the tap anyway shows the switch, and it flips back
  off. That is the old app's behaviour, and a visible failure beats a missing control.
- Over plain HTTP on the LAN the switch is absent, because the page is not a secure context.
  Test against `https://nosh.backson.boo`.

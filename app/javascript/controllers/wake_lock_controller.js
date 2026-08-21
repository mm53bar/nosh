import { Controller } from "@hotwired/stimulus"

// "Keep awake" — one switch over two unrelated ways of stopping the screen
// taking the recipe away mid-cook.
//
//   * the **Screen Wake Lock API**, which is what an iPad or a phone needs: the
//     device would otherwise sleep. This is the original backend.
//   * a **lease relayed by the host page**, which is what the kitchen Echo Show
//     needs. Its kiosk app already holds the screen on permanently, so a wake
//     lock buys nothing there; what takes the page away is the app's own
//     return-home timer (120s) and screensaver (300s), which no web API can
//     reach. The kiosk's own primitive for suppressing those is injected into
//     the main frame only, so nosh can't call it — the host relays instead, over
//     postMessage. Contract in docs/adr/20260821-keep-awake-is-two-backends.md.
//
// The two are independent: on the kiosk the wake lock always fails while the
// lease works, and on the iPad the reverse. So `checked` means "at least one
// hold is active", and a backend failing on its own never un-checks the switch.
// The whole control hides itself where neither backend can work, which is the
// discipline the wake-lock-only version already had.

const CHANNEL = "ks-keep-awake"
const VERSION = 1

// The host's listener isn't guaranteed to be installed before nosh loads, so
// "hello" is asked more than once before concluding nobody is out there. Under
// a second in total: past that the cook is looking at a row with no switch in
// it and has started reading step one.
const HELLO_DELAYS = [ 0, 250, 600, 1100 ]

export default class extends Controller {
  static targets = [ "toggle" ]

  connect() {
    this.wakeLock = null
    this.wakeLockUsable = null // null until probed — see probeWakeLock()
    this.host = null // { renewMs } once the host acks
    this.leaseHeld = false
    this.renewTimer = null
    this.helloTimers = []
    this.torn = false

    // Hidden until a backend proves itself, rather than shown until one fails:
    // a switch that appears late is a smaller lie than one that does nothing.
    // The markup ships `hidden` too, so a bundle that never loads leaves no
    // switch rather than a dead one.
    this.element.hidden = true

    this.handleMessage = (event) => this.receiveHostMessage(event)
    window.addEventListener("message", this.handleMessage)

    this.handleVisibilityChange = () => {
      if (document.visibilityState !== "visible") return

      // Re-probe if the first attempt never got to run: the spec rejects a
      // request from a hidden document, which is indistinguishable from being
      // blocked by policy, so a probe that ran hidden proves nothing.
      if (this.wakeLockUsable === null) this.probeWakeLock()

      // The OS drops the lock on a tab-switch; take it back if we still want it.
      if (this.toggleTarget.checked && this.wakeLockUsable && !this.wakeLock) this.acquireWakeLock()

      // Deliberately nothing here for the lease. It keeps renewing while the
      // page is hidden, because the kiosk's return-home timer keeps counting
      // while its app is backgrounded — releasing on hide would hand the cook
      // back the home screen with the recipe gone, which is the bug being fixed.
      // Frame death is what the lease's own expiry is for.
    }
    document.addEventListener("visibilitychange", this.handleVisibilityChange)

    this.probeWakeLock()
    this.sayHello()
  }

  disconnect() {
    // Requests in flight resolve after this; they check the flag rather than
    // reaching for a target that Stimulus may no longer find.
    this.torn = true
    window.removeEventListener("message", this.handleMessage)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    this.helloTimers.forEach(clearTimeout)
    this.releaseAll()
  }

  toggle() {
    if (this.toggleTarget.checked) {
      if (this.wakeLockUsable) this.acquireWakeLock()
      if (this.host) this.acquireLease()
    } else {
      this.releaseAll()
    }
  }

  // A hold is a hold, whichever backend has it. Called whenever one of them
  // changes hands, so the switch reports the union rather than the last event.
  reflectHolds() {
    if (this.torn || !this.hasToggleTarget) return

    this.toggleTarget.checked = Boolean(this.wakeLock) || this.leaseHeld
  }

  reveal() {
    this.element.hidden = false
  }

  // -- Screen Wake Lock ------------------------------------------------------

  // Whether a wake lock can be had here is not the same question as whether the
  // API is present. Inside the host's iframe `"wakeLock" in navigator` is true
  // while every request() rejects, because Screen Wake Lock is Permissions-
  // Policy gated to `self` by default and the iframe carries no `allow`
  // attribute — so a presence check would ship a dead switch on the one screen
  // this feature is for. Ask for a real lock and hand it straight back.
  async probeWakeLock() {
    if (!("wakeLock" in navigator)) {
      this.wakeLockUsable = false
      return
    }

    // Hidden document: don't ask yet, or the rejection reads as "blocked".
    if (document.visibilityState !== "visible") return

    try {
      const sentinel = await navigator.wakeLock.request("screen")
      await sentinel.release()
      if (this.torn) return

      this.wakeLockUsable = true
      this.reveal()

      // This can be the re-probe on becoming visible again, in which case the
      // switch may already be on and waiting for a backend to say yes.
      if (this.toggleTarget.checked && !this.wakeLock) this.acquireWakeLock()
    } catch {
      this.wakeLockUsable = false
    }
  }

  async acquireWakeLock() {
    try {
      const sentinel = await navigator.wakeLock.request("screen")

      // Un-checked — or the page left — while the request was in flight: don't
      // start holding something nobody asked for any more.
      if (this.torn || !this.toggleTarget.checked) return await sentinel.release()

      this.wakeLock = sentinel
      sentinel.addEventListener("release", () => {
        if (this.wakeLock === sentinel) this.wakeLock = null
        this.reflectHolds()
      })
    } catch {
      this.wakeLock = null
      this.reflectHolds()
    }
  }

  releaseWakeLock() {
    if (!this.wakeLock) return

    this.wakeLock.release()
    this.wakeLock = null
  }

  // -- Host lease ------------------------------------------------------------

  sayHello() {
    if (window.parent === window) return // not framed, so there's no host to ask

    this.helloTimers = HELLO_DELAYS.map((delay) =>
      setTimeout(() => {
        if (this.host) return
        this.postHost("hello")
      }, delay)
    )
  }

  receiveHostMessage(event) {
    const data = event.data
    if (!data || data.type !== CHANNEL || data.v !== VERSION || data.action !== "available") return
    if (this.host) return

    // The cadence comes from the ack, not from here: it's derived from a safety
    // timer on the host side and may change without nosh being redeployed.
    this.host = { renewMs: (data.renew_seconds || 30) * 1000 }
    this.reveal()

    // The ack can land after an eager tap, if the wake lock was the reason the
    // switch was already on screen.
    if (this.toggleTarget.checked) this.acquireLease()
  }

  // The host holds only while the newest "on" is younger than its lease, so a
  // frame that dies — the kiosk destroying the view, a reload, a crash —
  // releases by itself and no forgotten switch can wedge the kiosk awake.
  acquireLease() {
    if (this.renewTimer) return

    this.leaseHeld = true
    this.postHost("on")
    this.renewTimer = setInterval(() => this.postHost("on"), this.host.renewMs)
  }

  releaseLease() {
    if (this.renewTimer) {
      clearInterval(this.renewTimer)
      this.renewTimer = null
    }
    if (!this.leaseHeld) return

    this.leaseHeld = false
    this.postHost("off") // a courtesy: immediate, where the lease would take ~90s
  }

  // Always "*", never a guessed origin. The kiosk serves the Home Assistant
  // frontend through a loopback proxy, so the parent's origin is
  // http://127.0.0.1:<some port the app chose> rather than the hostname a human
  // types — and a wrong targetOrigin fails silently. Nothing here is a secret;
  // the host checks the origin, against an allowlist naming nosh.
  postHost(action) {
    // Never throws: this also runs from disconnect(), where the frame may be on
    // its way out, and an exception there would break teardown for whatever
    // else is on the element.
    try {
      window.parent.postMessage({ type: CHANNEL, v: VERSION, action: action }, "*")
    } catch {
      // Nothing useful to do — the lease expiring is the fallback for this.
    }
  }

  releaseAll() {
    this.releaseWakeLock()
    this.releaseLease()
  }
}

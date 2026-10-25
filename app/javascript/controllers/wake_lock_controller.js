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
// The whole control hides itself where neither backend can work.

const CHANNEL = "ks-keep-awake"
const VERSION = 1

// The host's listener isn't guaranteed to be installed before nosh loads, so
// "hello" is asked more than once before concluding nobody is out there. Under
// a second in total: past that the cook is looking at a row with no switch in
// it and has started reading step one.
const HELLO_DELAYS = [ 0, 250, 600, 1100 ]

export default class extends Controller {
  connect() {
    this.wakeLock = null
    this.wanted = false
    this.host = null // { renewMs } once the host acks
    this.leaseHeld = false
    this.renewTimer = null
    this.helloTimers = []
    this.torn = false

    // Unframed, the API being present is enough to show the switch; the lock is
    // only requested from the tap itself: a gesture-less probe at load is what
    // kept the switch hidden on the iPad. Framed, the API is present while every request is
    // refused by Permissions-Policy, so there only a host ack shows it.
    this.wakeLockUsable = "wakeLock" in navigator && window.isSecureContext && window.parent === window

    this.element.hidden = !this.wakeLockUsable

    this.handleMessage = (event) => this.receiveHostMessage(event)
    window.addEventListener("message", this.handleMessage)

    // The OS drops the lock whenever the page is hidden; take it back on return.
    this.handleVisibilityChange = () => {
      if (document.visibilityState === "visible" && this.wanted && this.wakeLockUsable && !this.wakeLock) {
        this.acquireWakeLock()
      }
    }
    document.addEventListener("visibilitychange", this.handleVisibilityChange)

    this.sayHello()
  }

  disconnect() {
    // Requests in flight resolve after this; they check the flag rather than
    // reaching for an element Stimulus may no longer find.
    this.torn = true
    window.removeEventListener("message", this.handleMessage)
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    this.helloTimers.forEach(clearTimeout)
    this.releaseAll()
  }

  get toggle() {
    return this.element.querySelector("input[type=checkbox]")
  }

  // Runs inside the tap's change event: the wake-lock request has to start here,
  // before any await, or it may no longer count as user-initiated.
  change() {
    this.wanted = this.toggle.checked
    if (this.wanted) {
      if (this.wakeLockUsable) this.acquireWakeLock()
      if (this.host) this.acquireLease()
    } else {
      this.releaseAll()
    }
  }

  // Un-checks only when nothing is holding; a backend failing alone isn't "off".
  reflectHolds() {
    if (this.torn || !this.toggle) return

    const held = Boolean(this.wakeLock) || this.leaseHeld
    if (!held) this.wanted = false
    this.toggle.checked = held
  }

  reveal() {
    this.element.hidden = false
  }

  // -- Screen Wake Lock ------------------------------------------------------

  async acquireWakeLock() {
    try {
      const sentinel = await navigator.wakeLock.request("screen")

      if (this.torn || !this.wanted) return await sentinel.release()

      this.wakeLock = sentinel
      // A release the OS made on hide keeps the switch on, so the
      // visibilitychange handler can take the lock back.
      sentinel.addEventListener("release", () => {
        if (this.wakeLock === sentinel) this.wakeLock = null
      })
    } catch {
      this.wakeLock = null
      this.reflectHolds()
    }
  }

  releaseWakeLock() {
    if (!this.wakeLock) return

    const sentinel = this.wakeLock
    this.wakeLock = null
    sentinel.release()
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
    if (this.wanted) this.acquireLease()
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

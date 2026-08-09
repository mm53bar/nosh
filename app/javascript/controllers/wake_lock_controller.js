import { Controller } from "@hotwired/stimulus"

// Requests a Screen Wake Lock while the toggle is checked, so an iPad/phone
// doesn't sleep mid-recipe. Ported from the old app's exact behavior: hide
// entirely if the browser has no Wake Lock API, release on uncheck, and
// re-acquire if the OS released it on a tab-switch/visibility change.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    if (!("wakeLock" in navigator)) {
      this.element.hidden = true
      return
    }

    this.wakeLock = null
    this.handleVisibilityChange = () => {
      if (document.visibilityState === "visible" && this.toggleTarget.checked && !this.wakeLock) this.acquire()
    }
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    this.release()
  }

  toggle() {
    if (this.toggleTarget.checked) {
      this.acquire()
    } else {
      this.release()
    }
  }

  async acquire() {
    try {
      this.wakeLock = await navigator.wakeLock.request("screen")
      this.wakeLock.addEventListener("release", () => {
        this.wakeLock = null
        this.toggleTarget.checked = false
      })
    } catch {
      this.toggleTarget.checked = false
    }
  }

  release() {
    if (this.wakeLock) {
      this.wakeLock.release()
      this.wakeLock = null
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Tap-to-track cooking progress, ported from the old app's exact behavior:
// tapping a step makes it "active" (highlighted, larger text); tapping the
// *active* step again marks it "done" (struck through) and auto-advances
// active to the next step. Tapping any other step just jumps focus there
// without touching existing done marks. No visible checkbox — the whole
// step is tappable.
export default class extends Controller {
  static targets = ["step", "progress"]

  connect() {
    this.active = null
  }

  tap(event) {
    const step = event.currentTarget
    const steps = this.stepTargets

    if (this.active === step) {
      step.classList.remove("active")
      step.classList.add("done")
      this.active = null

      const next = steps[steps.indexOf(step) + 1]
      if (next) {
        next.classList.add("active")
        this.active = next
        next.scrollIntoView({ behavior: "smooth", block: "nearest" })
      }
    } else {
      steps.forEach((s) => s.classList.remove("active"))
      step.classList.add("active")
      this.active = step
    }

    this.updateProgress()
  }

  updateProgress() {
    if (!this.hasProgressTarget) return

    const done = this.stepTargets.filter((s) => s.classList.contains("done")).length
    const total = this.stepTargets.length
    this.progressTarget.textContent = done === 0 ? "" : done === total ? "All done!" : `${done} of ${total} steps complete`
  }
}

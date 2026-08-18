import { Controller } from "@hotwired/stimulus"

// "Made it" for the kitchen screen — the one write that belongs in a kitchen,
// and a single tap at the end of cooking.
//
// It's a fetch rather than a form because the kiosk loads Home Assistant from a
// different site than nosh, so no session cookie reaches the iframe and there's
// no CSRF token to submit. JSON requests are exempt from forgery protection
// (see ApplicationController), and the result is reported in place — a flash
// message wouldn't survive a cookie-less redirect either.
export default class extends Controller {
  static targets = ["button"]
  static values = { url: String }

  async mark() {
    this.buttonTarget.disabled = true

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Accept": "application/json", "Content-Type": "application/json" }
      })

      if (!response.ok) throw new Error(response.status)

      this.buttonTarget.textContent = "✓ Made today"
    } catch {
      // Nowhere to redirect to and no flash to carry a message, so the button
      // says it itself and lets you try again.
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "Couldn't save — tap to retry"
    }
  }
}

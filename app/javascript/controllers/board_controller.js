import { Controller } from "@hotwired/stimulus"

// The shopping board. Every write is a JSON fetch rather than a form, because
// the kitchen screen frames this page from another site and no session cookie
// (so no CSRF token) reaches it — see docs/adr/20260812-framed-by-home-assistant.md.
export default class extends Controller {
  static targets = ["input", "message"]

  async toggle(event) {
    const button = event.currentTarget
    const on = button.dataset.on !== "true"
    const [model, field] = button.dataset.param.match(/^(\w+)\[(\w+)\]$/).slice(1)

    this.#show(button, on)
    try {
      await this.#send("PATCH", button.dataset.url, { [model]: { [field]: on } })
    } catch {
      this.#show(button, !on)
      this.messageTarget.textContent = "Couldn't save that — try again."
    }
  }

  async add(event) {
    event.preventDefault()
    const name = this.inputTarget.value.trim()
    if (!name) return

    const response = await this.#send("POST", "/write_ins.json", { write_in: { name } }, { allow: [422] })
    if (response.ok) return window.location.reload()

    const body = await response.json()
    this.messageTarget.textContent = body.message
  }

  async promote(event) {
    const button = event.currentTarget
    const aisle = button.parentElement.querySelector("select").value

    const response = await this.#send("POST", button.dataset.url, { aisle_id: aisle }, { allow: [422] })
    if (response.ok) return window.location.reload()

    const body = await response.json()
    this.messageTarget.textContent = body.errors.join(" ")
  }

  #show(button, on) {
    button.dataset.on = on
    if (button.hasAttribute("aria-pressed")) button.setAttribute("aria-pressed", on)
  }

  async #send(method, url, body, { allow = [] } = {}) {
    const response = await fetch(url, {
      method,
      headers: { "Accept": "application/json", "Content-Type": "application/json" },
      body: JSON.stringify(body)
    })
    if (!response.ok && !allow.includes(response.status)) throw new Error(response.status)
    return response
  }
}

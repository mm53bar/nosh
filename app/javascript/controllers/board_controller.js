import { Controller } from "@hotwired/stimulus"

const PENDING_TOAST = "board:toast"

// The shopping board. Every write is a JSON fetch rather than a form, because
// the kitchen screen frames this page from another site and no session cookie
// (so no CSRF token) reaches it — see docs/adr/20260812-framed-by-home-assistant.md.
export default class extends Controller {
  static targets = ["add"]

  connect() {
    // The vendored autocomplete ends every pick or Enter with form.submit(), a
    // full navigation that skips submit handlers. Its `autocomplete:submit`
    // event, dispatched just before, is the hook; the navigation must not run.
    const form = this.hasAddTarget && this.addTarget.querySelector("form")
    if (form) form.submit = () => {}

    this.#showPendingToast()
  }

  async toggle(event) {
    const input = event.currentTarget
    const on = input.checked
    const [model, field] = input.dataset.param.match(/^(\w+)\[(\w+)\]$/).slice(1)

    try {
      await this.#send("PATCH", input.dataset.url, { [model]: { [field]: on } })
    } catch {
      input.checked = !on
      this.#toast("Couldn't save that — try again.", "error")
    }
  }

  async add(event) {
    const name = event.detail.value?.trim()
    if (!name) return

    const response = await this.#send("POST", "/write_ins.json", { write_in: { name } }, { allow: [422] })
    const body = await response.json()
    this.addTarget.querySelector("input").value = ""

    if (body.kind === "staple") {
      const tab = this.element.querySelector(`input[data-staple="${CSS.escape(body.staple)}"]`)
      if (tab) tab.checked = true
      this.#toast(body.message, "success")
    } else if (body.kind === "group") {
      this.#toast(body.message, "warning")
    } else {
      this.#reloadWith(body.message)
    }
  }

  async promote(event) {
    const button = event.currentTarget
    const aisle = button.parentElement.querySelector("select").value

    const response = await this.#send("POST", button.dataset.url, { aisle_id: aisle }, { allow: [422] })
    const body = await response.json()
    if (response.ok) return this.#reloadWith(`${body.staple} has a tab now.`)

    this.#toast(body.errors.join(" "), "error")
  }

  #toast(message, type) {
    window.toast?.(message, { type })
  }

  // A toast doesn't survive the reload that shows a new write-in, so it rides
  // across in sessionStorage. Storage can be unavailable in a kiosk WebView;
  // losing the toast then is fine, losing the reload is not.
  #reloadWith(message) {
    try { sessionStorage.setItem(PENDING_TOAST, message) } catch {}
    window.location.reload()
  }

  #showPendingToast() {
    let message = null
    try {
      message = sessionStorage.getItem(PENDING_TOAST)
      sessionStorage.removeItem(PENDING_TOAST)
    } catch {}
    if (message) requestAnimationFrame(() => this.#toast(message, "success"))
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

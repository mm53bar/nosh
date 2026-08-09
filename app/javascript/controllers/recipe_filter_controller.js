import { Controller } from "@hotwired/stimulus"

// Client-side filtering of the recipe grid — debounced search plus a
// sidebar of single-select filter links (type, effort, rating, cuisine),
// ported from the old app's exact click-to-filter behavior: each group
// holds at most one active value, "All" clears that group, rating uses
// "N and up" thresholds rather than an exact match. No server round-trip —
// with a few hundred recipes at most, filtering the already-rendered cards
// in the browser is simpler and snappier than a Turbo Frame re-render.
export default class extends Controller {
  static targets = ["input", "card", "empty", "count", "filterLink", "clearAll"]
  static values = { debounce: { type: Number, default: 200 } }

  connect() {
    this.state = {}
    this.timeout = null
    this.filter()
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.filter(), this.debounceValue)
  }

  select(event) {
    event.preventDefault()
    const { facet, value } = event.currentTarget.dataset
    this.state[facet] = value

    this.filterLinkTargets
      .filter((link) => link.dataset.facet === facet)
      .forEach((link) => this.setActive(link, link.dataset.value === value))

    this.filter()
  }

  clear(event) {
    if (event) event.preventDefault()
    this.state = {}
    this.inputTarget.value = ""
    this.filterLinkTargets.forEach((link) => this.setActive(link, link.dataset.value === ""))
    this.filter()
  }

  setActive(link, active) {
    link.classList.toggle("text-amber-700", active)
    link.classList.toggle("font-semibold", active)
    link.classList.toggle("text-stone-600", !active)
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    let visibleCount = 0
    this.cardTargets.forEach((card) => {
      const matchesSearch = !query || card.dataset.searchable.includes(query)
      const matchesFacets = Object.entries(this.state).every(([facet, value]) => {
        if (!value) return true
        if (facet === "rating") return this.matchesRating(card, value)
        if (facet === "equipment") return (card.dataset.equipment || "").split("|").includes(value)
        return (card.dataset[facet] || "") === value
      })
      const visible = matchesSearch && matchesFacets
      card.hidden = !visible
      if (visible) visibleCount++
    })

    if (this.hasCountTarget) this.countTarget.textContent = `${visibleCount} recipe${visibleCount === 1 ? "" : "s"}`
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visibleCount !== 0
    if (this.hasClearAllTarget) {
      const anyActive = this.inputTarget.value || Object.values(this.state).some((v) => v)
      this.clearAllTarget.hidden = !anyActive
    }
  }

  matchesRating(card, value) {
    const rating = card.dataset.rating
    if (value === "unrated") return rating === "unrated"
    return rating !== "unrated" && parseInt(rating, 10) >= parseInt(value, 10)
  }
}

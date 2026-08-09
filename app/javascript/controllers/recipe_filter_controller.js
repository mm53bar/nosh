import { Controller } from "@hotwired/stimulus"

// Client-side filtering of the recipe grid — debounced search plus a sidebar
// of facet checkboxes (cuisine, meal type, effort, rating). No server
// round-trip: with a few hundred recipes at most, filtering the
// already-rendered cards in the browser is simpler and snappier than a
// Turbo Frame re-render, and matches how the old app's recipe list worked.
export default class extends Controller {
  static targets = ["input", "card", "empty", "count", "facetCheckbox"]
  static values = { debounce: { type: Number, default: 200 } }

  connect() {
    this.timeout = null
    this.filter()
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.filter(), this.debounceValue)
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    const activeFacets = this.groupedActiveFacets()

    let visibleCount = 0
    this.cardTargets.forEach((card) => {
      const matchesSearch = !query || card.dataset.searchable.includes(query)
      const matchesFacets = Object.entries(activeFacets).every(([facet, values]) => {
        return values.length === 0 || values.includes(card.dataset[facet] || "")
      })
      const visible = matchesSearch && matchesFacets
      card.hidden = !visible
      if (visible) visibleCount++
    })

    if (this.hasCountTarget) this.countTarget.textContent = visibleCount
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visibleCount !== 0
  }

  clear() {
    this.inputTarget.value = ""
    this.facetCheckboxTargets.forEach((checkbox) => { checkbox.checked = false })
    this.filter()
  }

  groupedActiveFacets() {
    const grouped = {}
    this.facetCheckboxTargets.forEach((checkbox) => {
      const facet = checkbox.dataset.facet
      grouped[facet] ||= []
      if (checkbox.checked) grouped[facet].push(checkbox.value)
    })
    return grouped
  }
}

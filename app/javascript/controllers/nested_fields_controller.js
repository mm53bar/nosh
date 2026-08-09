import { Controller } from "@hotwired/stimulus"

// Adds/removes nested-attribute rows (recipe ingredients, steps) without a
// full page reload. The <template> holds one blank fields_for row keyed by
// child_index: "NEW_RECORD"; add() swaps that placeholder for a unique id and
// appends the row. remove() soft-deletes persisted rows via _destroy (so
// accepts_nested_attributes_for's allow_destroy can remove them on save) and
// hard-removes rows that were never saved.
export default class extends Controller {
  static targets = ["rows", "template"]

  add(event) {
    event.preventDefault()
    const uniqueId = new Date().getTime()
    this.rowsTarget.insertAdjacentHTML(
      "beforeend",
      this.templateTarget.innerHTML.replace(/NEW_RECORD/g, uniqueId)
    )
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-nested-fields-target='row']")
    const destroyField = row.querySelector("input[name*='_destroy']")
    if (destroyField && destroyField.getAttribute("name").includes("_attributes")) {
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }
  }
}

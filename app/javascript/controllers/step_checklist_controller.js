import { Controller } from "@hotwired/stimulus"

// Strikes through a recipe step's text when its checkbox is checked — a
// lightweight "cooking checklist" while working through a recipe.
export default class extends Controller {
  toggle(event) {
    const text = event.currentTarget.closest("label").querySelector("span")
    text.classList.toggle("line-through", event.currentTarget.checked)
    text.classList.toggle("text-stone-400", event.currentTarget.checked)
  }
}

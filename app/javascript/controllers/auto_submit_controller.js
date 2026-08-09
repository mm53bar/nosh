import { Controller } from "@hotwired/stimulus"

// Submits the controller's form as soon as a field inside it changes — used
// for pickers (e.g. "add a recipe to this day") with no separate submit button.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

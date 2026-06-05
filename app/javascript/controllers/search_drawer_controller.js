import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "query", "queryText"]

  open(event) {
    event.preventDefault()

    if (this.hasQueryTextTarget) {
      this.queryTextTarget.textContent = this.queryTarget.value.trim()
    }

    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}

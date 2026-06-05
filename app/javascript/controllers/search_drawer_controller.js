import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "query", "queryText"]

  open(event) {
    if (this.hasQueryTextTarget) {
      this.queryTextTarget.textContent = this.queryTarget.value.trim()
    }

    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }
  }

  close() {
    this.dialogTarget.close()
  }
}

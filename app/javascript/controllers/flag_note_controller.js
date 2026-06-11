import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  clear() {
    if (!this.hasInputTarget) return

    this.inputTarget.value = ""
    this.element.requestSubmit()
  }
}

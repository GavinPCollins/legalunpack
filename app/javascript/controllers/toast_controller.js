import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 4500 } }

  connect() {
    this.timeout = window.setTimeout(() => this.close(), this.delayValue)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
  }

  close() {
    this.element.classList.add("opacity-0", "translate-y-1")
    window.setTimeout(() => this.element.remove(), 180)
  }
}

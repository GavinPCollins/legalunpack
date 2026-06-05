import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    active: Boolean,
    interval: { type: Number, default: 2500 },
    url: String
  }

  connect() {
    if (this.activeValue) this.schedule()
  }

  disconnect() {
    this.clear()
  }

  schedule() {
    this.clear()
    this.timeout = window.setTimeout(() => this.refresh(), this.intervalValue)
  }

  clear() {
    if (this.timeout) window.clearTimeout(this.timeout)
  }

  async refresh() {
    if (!this.hasUrlValue) return

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html" },
        credentials: "same-origin"
      })

      if (response.ok) {
        this.element.outerHTML = await response.text()
      } else {
        this.schedule()
      }
    } catch {
      this.schedule()
    }
  }
}

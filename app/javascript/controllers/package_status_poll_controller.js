import { Controller } from "@hotwired/stimulus"

// Refreshes the package dashboard while one or more files are being analyzed.
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

      if (!response.ok) {
        this.schedule()
        return
      }

      const documentFragment = new DOMParser().parseFromString(await response.text(), "text/html")
      const replacement = documentFragment.getElementById(this.element.id)

      if (replacement) {
        this.element.replaceWith(replacement)
      } else {
        this.schedule()
      }
    } catch {
      this.schedule()
    }
  }
}

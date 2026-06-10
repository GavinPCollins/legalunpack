import { Controller } from "@hotwired/stimulus"

// Refreshes the package dashboard while one or more files are being analyzed.
export default class extends Controller {
  static targets = ["analysisAction"]

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

  markAnalysisStarted() {
    if (this.hasAnalysisActionTarget) {
      this.analysisActionTarget.innerHTML = `
        <div class="flex items-center gap-1.5 text-cyan-800">
          <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" class="size-3.5 animate-spin">
            <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2" class="opacity-25"></circle>
            <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" stroke-width="2" stroke-linecap="round"></path>
          </svg>
          <span class="text-sm font-medium">Analyzing file...</span>
        </div>
      `
    }

    this.activeValue = true
    this.schedule()
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

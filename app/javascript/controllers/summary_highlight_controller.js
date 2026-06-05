// CODEX file summary
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["match"]

  connect() {
    if (!this.hasMatchTarget) return

    requestAnimationFrame(() => {
      this.matchTarget.scrollIntoView({ behavior: "smooth", block: "center" })
      this.matchTarget.focus?.({ preventScroll: true })
    })
  }
}

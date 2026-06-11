// CODEX file summary
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["match"]

  connect() {
    if (!this.hasMatchTarget) return

    this.currentIndex = this.initialMatchIndex()

    requestAnimationFrame(() => {
      this.focusCurrentMatch()
    })
  }

  focusCurrentMatch() {
    const match = this.matchTargets[this.currentIndex]

    match.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  initialMatchIndex() {
    const targetId = window.location.hash?.slice(1)
    if (!targetId) return 0

    const container = document.getElementById(targetId)
    if (!container) return 0

    const index = this.matchTargets.findIndex((match) => container.contains(match))

    return index >= 0 ? index : 0
  }
}

// CODEX file summary
import { Controller } from "@hotwired/stimulus"

const focusedClauseClasses = ["border-cyan-300", "bg-cyan-50/40", "ring-2", "ring-cyan-100"]

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

  jumpToClause(event) {
    const targetId = event.currentTarget.hash?.slice(1)
    if (!targetId) return

    const clause = document.getElementById(decodeURIComponent(targetId))
    if (!clause) return

    event.preventDefault()
    history.pushState(null, "", `#${clause.id}`)
    clause.scrollIntoView({ behavior: "smooth", block: "start" })
    this.highlightClause(clause)
    clause.focus({ preventScroll: true })
  }

  highlightClause(clause) {
    this.element.querySelectorAll("[id^='clause_']").forEach((candidate) => {
      candidate.classList.remove(...focusedClauseClasses)
      candidate.classList.add("border-neutral-200")
    })

    clause.classList.remove("border-neutral-200")
    clause.classList.add(...focusedClauseClasses)
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

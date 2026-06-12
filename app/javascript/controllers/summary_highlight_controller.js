// CODEX file summary
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["match"]

  connect() {
    const hashTarget = this.scrollToHashTarget()

    if (!this.hasMatchTarget || hashTarget?.id?.startsWith("clause_")) return

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
    clause.focus({ preventScroll: true })
  }

  scrollToHashTarget() {
    const targetId = window.location.hash?.slice(1)
    if (!targetId) return

    const target = document.getElementById(decodeURIComponent(targetId))
    if (!target) return

    requestAnimationFrame(() => {
      target.scrollIntoView({ block: "start" })
      target.focus({ preventScroll: true })
    })

    return target
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

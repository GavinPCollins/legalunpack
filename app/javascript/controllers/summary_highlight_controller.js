// CODEX file summary
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["controls", "controlsSlot", "match"]

  static activeClasses = ["bg-cyan-100", "ring-2", "ring-cyan-700", "ring-offset-2"]

  connect() {
    if (!this.hasMatchTarget) return

    this.currentIndex = this.initialMatchIndex()
    this.handleResize = this.lockControlsPosition.bind(this)
    window.addEventListener("resize", this.handleResize)

    requestAnimationFrame(() => {
      this.lockControlsPosition()
      this.focusCurrentMatch()
    })
  }

  disconnect() {
    if (!this.handleResize) return

    window.removeEventListener("resize", this.handleResize)
  }

  next() {
    if (!this.hasMatchTarget) return

    this.currentIndex = (this.currentIndex + 1) % this.matchTargets.length
    this.focusCurrentMatch()
  }

  previous() {
    if (!this.hasMatchTarget) return

    this.currentIndex = (this.currentIndex - 1 + this.matchTargets.length) % this.matchTargets.length
    this.focusCurrentMatch()
  }

  focusCurrentMatch() {
    const match = this.matchTargets[this.currentIndex]

    this.markActiveMatch(match)
    match.scrollIntoView({ behavior: "smooth", block: "center" })
    match.focus?.({ preventScroll: true })
  }

  markActiveMatch(activeMatch) {
    this.matchTargets.forEach((match) => {
      match.classList.remove(...this.constructor.activeClasses)
      match.removeAttribute("aria-current")
    })

    activeMatch.classList.add(...this.constructor.activeClasses)
    activeMatch.setAttribute("aria-current", "true")
  }

  lockControlsPosition() {
    if (!this.hasControlsTarget || !this.hasControlsSlotTarget) return

    const slot = this.controlsSlotTarget.getBoundingClientRect()
    const controls = this.controlsTarget.getBoundingClientRect()

    this.controlsSlotTarget.style.minHeight = `${controls.height}px`
    this.controlsTarget.style.position = "fixed"
    this.controlsTarget.style.top = `${Math.max(slot.top, 0)}px`
    this.controlsTarget.style.left = `${slot.left}px`
    this.controlsTarget.style.width = `${slot.width}px`
    this.controlsTarget.classList.add("z-20")
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

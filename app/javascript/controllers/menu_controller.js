import { Controller } from "@hotwired/stimulus"

// Shared behaviour for native <details>-based menus.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.closeOutside = this.closeOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.closeOtherMenu = this.closeOtherMenu.bind(this)
    this.announceOpen = this.announceOpen.bind(this)
    this.positionPanel = this.positionPanel.bind(this)

    document.addEventListener("click", this.closeOutside)
    window.addEventListener("keydown", this.closeOnEscape)
    window.addEventListener("app:menu-opened", this.closeOtherMenu)
    window.addEventListener("resize", this.positionPanel)
    document.addEventListener("scroll", this.positionPanel, true)
    this.element.addEventListener("toggle", this.announceOpen)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOutside)
    window.removeEventListener("keydown", this.closeOnEscape)
    window.removeEventListener("app:menu-opened", this.closeOtherMenu)
    window.removeEventListener("resize", this.positionPanel)
    document.removeEventListener("scroll", this.positionPanel, true)
    this.element.removeEventListener("toggle", this.announceOpen)
  }

  closeOutside(event) {
    if (this.element.open && !this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.element.open) return

    this.close()
    this.element.querySelector("summary")?.focus()
  }

  closeOtherMenu(event) {
    if (event.detail.menu !== this.element) {
      this.close()
    }
  }

  announceOpen() {
    if (!this.element.open) return

    window.dispatchEvent(new CustomEvent("app:menu-opened", {
      detail: { menu: this.element }
    }))

    window.requestAnimationFrame(this.positionPanel)
  }

  positionPanel() {
    if (!this.element.open || !this.hasPanelTarget) return

    const trigger = this.element.querySelector("summary")
    if (!trigger) return

    const viewportMargin = 8
    const menuGap = 8
    const triggerRect = trigger.getBoundingClientRect()
    const panelRect = this.panelTarget.getBoundingClientRect()
    const spaceBelow = window.innerHeight - triggerRect.bottom
    const spaceAbove = triggerRect.top
    const openBelow = spaceBelow >= panelRect.height + menuGap || spaceBelow >= spaceAbove
    const desiredTop = openBelow
      ? triggerRect.bottom + menuGap
      : triggerRect.top - panelRect.height - menuGap
    const desiredLeft = triggerRect.right - panelRect.width

    const maximumTop = Math.max(
      viewportMargin,
      window.innerHeight - panelRect.height - viewportMargin
    )
    const top = Math.min(
      Math.max(desiredTop, viewportMargin),
      maximumTop
    )
    const left = Math.min(
      Math.max(desiredLeft, viewportMargin),
      window.innerWidth - panelRect.width - viewportMargin
    )

    this.panelTarget.style.top = `${top}px`
    this.panelTarget.style.left = `${left}px`
  }

  close() {
    this.element.removeAttribute("open")
  }
}

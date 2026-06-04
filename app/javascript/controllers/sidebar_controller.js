import { Controller } from "@hotwired/stimulus"

// Controls the mobile sidebar drawer.
// Desktop sidebar visibility is handled by responsive Tailwind classes.
export default class extends Controller {
  static targets = ["drawer", "backdrop", "panel"]

  connect() {
    this.close()
  }

  open() {
    this.drawerTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("opacity-0")
    this.panelTarget.classList.remove("-translate-x-full")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.backdropTarget.classList.add("opacity-0")
    this.panelTarget.classList.add("-translate-x-full")
    document.body.classList.remove("overflow-hidden")

    window.setTimeout(() => {
      if (this.panelTarget.classList.contains("-translate-x-full")) {
        this.drawerTarget.classList.add("hidden")
      }
    }, 200)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}

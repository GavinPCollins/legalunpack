import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    const dialog = this.findDialog(event?.params?.dialog)
    dialog.classList.remove("hidden")
  }

  close(event) {
    const dialog = this.findDialog(event?.params?.dialog)
    dialog.classList.add("hidden")
  }

  findDialog(name) {
    if (!name) return this.dialogTarget

    return this.dialogTargets.find((dialog) => dialog.dataset.modalName === name) || this.dialogTarget
  }
}

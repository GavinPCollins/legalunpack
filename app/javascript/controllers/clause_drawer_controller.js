import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    this.findDialog(event?.params?.dialog, event).showModal()
  }

  close(event) {
    this.findDialog(event?.params?.dialog, event).close()
  }

  findDialog(id, event) {
    if (id) {
      return document.getElementById(id)
    }

    const containingDialog = event?.currentTarget?.closest("dialog")
    if (containingDialog) {
      return containingDialog
    }

    return this.dialogTarget
  }
}

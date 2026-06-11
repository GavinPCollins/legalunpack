import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { flagId: Number, flagName: String }

  submit(event) {
    event.preventDefault()
    if (!this.hasInputTarget) return

    const question = this.inputTarget.value.trim()
    if (!question) return

    const dialog = this.element.closest("dialog")
    if (dialog?.open) dialog.close()

    window.requestAnimationFrame(() => {
      window.dispatchEvent(new CustomEvent("ai-chat:ask", {
        detail: {
          question,
          target: "flag",
          targetId: this.hasFlagIdValue ? this.flagIdValue : null
        }
      }))
    })
  }
}

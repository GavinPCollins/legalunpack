import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = { url: String }

  async fillFromFile(event) {
    const file = event.target.files?.[0]
    await this.autofill(file)
  }

  async fillFromSelectedFiles(event) {
    const file = event.detail?.files?.[0]
    await this.autofill(file)
  }

  async autofill(file) {
    if (!file || !this.hasUrlValue) return

    this.setStatus("Detecting source details...")

    const formData = new FormData()
    formData.append("source_file", file)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: formData
      })
      const data = await response.json()

      if (!response.ok) throw new Error(data.error || "Autofill failed")

      this.applyMetadata(data.metadata || {})
      this.setStatus("Source details detected. Review them before adding the resource.")
    } catch (error) {
      this.setStatus(error.message || "Source details could not be detected.")
    }
  }

  applyMetadata(metadata) {
    Object.entries(metadata).forEach(([name, value]) => {
      if (!value) return

      const field = this.element.querySelector(`[name="legal_source[${name}]"]`)
      if (!field || field.value.trim()) return

      field.value = value
      field.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}

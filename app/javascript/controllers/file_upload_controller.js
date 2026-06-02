import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "dropzone"]

  connect() {
    this.selectedFiles = []
  }

  select() {
    this.addFiles(this.inputTarget.files)
  }

  dragover(event) {
    event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    this.addFiles(event.dataTransfer.files)
  }

  remove(event) {
    this.selectedFiles.splice(Number(event.currentTarget.dataset.index), 1)
    this.syncInput()
    this.render()
  }

  addFiles(files) {
    this.selectedFiles = this.selectedFiles.concat(Array.from(files))
    this.syncInput()
    this.render()
  }

  syncInput() {
    const transfer = new DataTransfer()

    this.selectedFiles.forEach((file) => {
      transfer.items.add(file)
    })

    this.inputTarget.files = transfer.files
  }

  render() {
    this.listTarget.innerHTML = ""

    this.selectedFiles.forEach((file, index) => {
      const item = document.createElement("li")
      const fileName = document.createElement("span")
      const removeButton = document.createElement("button")

      fileName.textContent = file.name
      removeButton.type = "button"
      removeButton.className = "remove-file"
      removeButton.textContent = "Delete"
      removeButton.dataset.index = index
      removeButton.dataset.action = "file-upload#remove"

      item.append(fileName, removeButton)
      this.listTarget.appendChild(item)
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "thread"]
  static values = { url: String }

  open() {
    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }

    this.loadHistory()
  }

  close() {
    this.dialogTarget.close()
  }

  async loadHistory() {
    if (!this.hasUrlValue || !this.hasThreadTarget) return

    this.threadTarget.innerHTML = ""
    this.renderStatus("Loading chat history...")

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" }
      })

      if (!response.ok) throw new Error(`Chat history request failed: ${response.status}`)

      const data = await response.json()
      this.renderMessages(data.messages || [])
    } catch (_error) {
      this.threadTarget.innerHTML = ""
      this.renderStatus("Chat history could not be loaded.")
    }
  }

  renderMessages(messages) {
    this.threadTarget.innerHTML = ""

    if (messages.length === 0) {
      this.renderStatus("Ask a question about this package.")
      return
    }

    messages.forEach((message) => {
      this.threadTarget.appendChild(this.messageElement(message))
    })
  }

  renderStatus(message) {
    const wrapper = document.createElement("div")
    wrapper.className = "ai-chat-message ai-chat-message-ai"

    const avatar = document.createElement("div")
    avatar.className = "ai-chat-avatar"
    avatar.setAttribute("aria-hidden", "true")
    avatar.textContent = "AI"

    const bubble = document.createElement("div")
    bubble.className = "ai-chat-bubble ai-chat-bubble-ai"

    const text = document.createElement("p")
    text.className = "ai-chat-text"
    text.textContent = message

    bubble.appendChild(text)
    wrapper.appendChild(avatar)
    wrapper.appendChild(bubble)
    this.threadTarget.appendChild(wrapper)
  }

  messageElement(message) {
    const isUser = message.role === "user"
    const wrapper = document.createElement("div")
    wrapper.className = `ai-chat-message ${isUser ? "ai-chat-message-user" : "ai-chat-message-ai"}`

    const avatar = document.createElement("div")
    avatar.className = `ai-chat-avatar${isUser ? " ai-chat-avatar-user" : ""}`
    avatar.setAttribute("aria-hidden", "true")
    avatar.textContent = isUser ? "You" : "AI"

    const bubble = document.createElement("div")
    bubble.className = `ai-chat-bubble ${isUser ? "ai-chat-bubble-user" : "ai-chat-bubble-ai"}`

    bubble.appendChild(this.metaElement(message, isUser))

    const text = document.createElement("p")
    text.className = "ai-chat-text"
    text.textContent = message.content || ""
    bubble.appendChild(text)

    if (isUser) {
      wrapper.appendChild(bubble)
      wrapper.appendChild(avatar)
    } else {
      wrapper.appendChild(avatar)
      wrapper.appendChild(bubble)
    }

    return wrapper
  }

  metaElement(message, isUser) {
    const meta = document.createElement("div")
    meta.className = `ai-chat-meta${isUser ? " ai-chat-meta-user" : ""}`

    const sender = document.createElement("span")
    sender.className = "ai-chat-sender"
    sender.textContent = isUser ? "You" : "LegalUnpack AI"
    meta.appendChild(sender)

    if (message.created_at) {
      const time = document.createElement("time")
      time.className = "ai-chat-time"
      time.dateTime = message.created_at
      time.textContent = this.formatTime(message.created_at)
      meta.appendChild(time)
    }

    return meta
  }

  formatTime(value) {
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return ""

    return new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit"
    }).format(date)
  }
}

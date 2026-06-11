import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "thread", "input", "submitButton"]
  static values = { url: String }

  connect() {
    this.prefillFromEvent = this.prefillFromEvent.bind(this)
    this.askFromEvent = this.askFromEvent.bind(this)
    window.addEventListener("ai-chat:prefill", this.prefillFromEvent)
    window.addEventListener("ai-chat:ask", this.askFromEvent)
  }

  disconnect() {
    window.removeEventListener("ai-chat:prefill", this.prefillFromEvent)
    window.removeEventListener("ai-chat:ask", this.askFromEvent)
  }

  open() {
    this.show()
    this.loadHistory()
  }

  show() {
    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }
  }

  prefill(event) {
    this.open()

    if (this.hasInputTarget) {
      this.inputTarget.value = event.params.question || ""
      this.inputTarget.focus()
    }
  }

  prefillFromEvent(event) {
    this.open()

    if (this.hasInputTarget) {
      this.inputTarget.value = event.detail?.question || ""
      this.inputTarget.focus()
    }
  }

  async askFromEvent(event) {
    const question = event.detail?.question?.trim()
    if (!question) return

    this.show()
    await this.loadHistory()
    await this.submitQuestion(question, {
      target: event.detail?.target,
      targetId: event.detail?.targetId
    })
  }

  async ask(event) {
    const question = event.params.question?.trim()
    if (!question) return

    this.show()
    await this.loadHistory()
    await this.submitQuestion(question, {
      target: event.params.target,
      targetId: event.params.targetId
    })
  }

  close() {
    this.dialogTarget.close()
  }

  submitOnEnter(event) {
    if (event.key !== "Enter" || event.shiftKey) return

    event.preventDefault()
    this.submit(event)
  }

  async submit(event) {
    event.preventDefault()
    if (!this.hasInputTarget || !this.hasThreadTarget || !this.hasUrlValue) return

    const question = this.inputTarget.value.trim()
    if (!question) return

    await this.submitQuestion(question)
  }

  async submitQuestion(question, options = {}) {
    if (!this.hasInputTarget || !this.hasThreadTarget || !this.hasUrlValue) return

    this.setFormDisabled(true)
    this.clearPlaceholderStatus()
    const pendingUserMessage = this.messageElement({
      role: "user",
      content: question,
      created_at: new Date().toISOString()
    })
    const thinkingMessage = this.statusElement("Thinking...")

    this.threadTarget.appendChild(pendingUserMessage)
    this.threadTarget.appendChild(thinkingMessage)
    this.scrollToLatest()
    this.inputTarget.value = ""

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({
          question,
          target: options.target,
          target_id: options.targetId
        })
      })

      const data = await response.json()
      pendingUserMessage.remove()
      thinkingMessage.remove()

      if (data.user_message) this.threadTarget.appendChild(this.messageElement(data.user_message))
      if (data.assistant_message) this.threadTarget.appendChild(this.messageElement(data.assistant_message))

      if (!response.ok && !data.assistant_message) {
        this.renderStatus(data.error || "Chatbot response failed. Please try again.")
      }
    } catch (_error) {
      pendingUserMessage.remove()
      thinkingMessage.remove()
      this.renderStatus("Chatbot response failed. Please try again.")
    } finally {
      this.setFormDisabled(false)
      this.inputTarget.focus()
      this.scrollToLatest()
    }
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
    this.scrollToLatest()
  }

  clearPlaceholderStatus() {
    const onlyMessage = this.threadTarget.querySelector(".ai-chat-message")
    if (!onlyMessage || this.threadTarget.children.length !== 1) return

    const text = onlyMessage.querySelector(".ai-chat-text")?.textContent
    if (text === "Ask a question about this package.") {
      this.threadTarget.innerHTML = ""
    }
  }

  renderStatus(message) {
    this.threadTarget.appendChild(this.statusElement(message))
    this.scrollToLatest()
  }

  statusElement(message) {
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
    return wrapper
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

    if (!isUser) {
      const references = this.referencesElement(message.legal_references || [])
      if (references) bubble.appendChild(references)
    }

    if (isUser) {
      wrapper.appendChild(bubble)
      wrapper.appendChild(avatar)
    } else {
      wrapper.appendChild(avatar)
      wrapper.appendChild(bubble)
    }

    return wrapper
  }

  referencesElement(references) {
    if (!references.length) return null

    const wrapper = document.createElement("div")
    wrapper.className = "ai-chat-references"

    const heading = document.createElement("div")
    heading.className = "ai-chat-references-heading"
    heading.textContent = "References used"
    wrapper.appendChild(heading)

    references.forEach((reference) => {
      const details = document.createElement("details")
      details.className = "ai-chat-reference"

      const summary = document.createElement("summary")
      summary.className = "ai-chat-reference-summary"
      summary.textContent = this.referenceTitle(reference)
      details.appendChild(summary)

      const meta = document.createElement("div")
      meta.className = "ai-chat-reference-meta"
      meta.textContent = [
        reference.citation,
        reference.publisher,
        reference.jurisdiction,
        reference.source_type,
        reference.authority_level
      ].filter(Boolean).join(" | ")
      if (meta.textContent) details.appendChild(meta)

      const content = document.createElement("p")
      content.className = "ai-chat-reference-content"
      content.textContent = reference.content || ""
      details.appendChild(content)

      wrapper.appendChild(details)
    })

    return wrapper
  }

  referenceTitle(reference) {
    const parts = [
      `[${reference.label}]`,
      reference.citation || reference.title
    ].filter(Boolean)

    if (!reference.citation && reference.heading) parts.push(reference.heading)

    return parts.join(" ")
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

  setFormDisabled(disabled) {
    this.inputTarget.disabled = disabled

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = disabled
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  scrollToLatest() {
    this.threadTarget.lastElementChild?.scrollIntoView({ block: "end" })
  }
}

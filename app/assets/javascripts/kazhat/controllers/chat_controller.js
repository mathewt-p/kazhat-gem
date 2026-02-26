import { Controller } from "@hotwired/stimulus"
import { createSubscription } from "../lib/cable"
import { api } from "../lib/api"

export default class extends Controller {
  static targets = ["messages", "input", "typingIndicator"]

  static values = {
    conversationId: Number,
    userId: Number
  }

  connect() {
    this.loadMessages()
    this.subscribeToChannel()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
  }

  async loadMessages() {
    try {
      const data = await api.get(`/conversations/${this.conversationIdValue}/messages`)
      if (data.messages) {
        this.renderMessages(data.messages.reverse())
        this.scrollToBottom()
      }
    } catch (error) {
      console.error("Failed to load messages:", error)
    }
  }

  subscribeToChannel() {
    this.subscription = createSubscription("MessageChannel",
      { conversation_id: this.conversationIdValue },
      {
        received: (data) => this.handleReceived(data)
      }
    )
  }

  handleReceived(data) {
    switch (data.type) {
      case "new_message":
        this.appendMessage(data.message)
        this.scrollToBottom()
        break
      case "typing":
        this.handleTypingIndicator(data)
        break
    }
  }

  async sendMessage(event) {
    event.preventDefault()

    if (!this.hasInputTarget) return
    const body = this.inputTarget.value.trim()
    if (!body) return

    try {
      await api.post(`/conversations/${this.conversationIdValue}/messages`, { body })
      this.inputTarget.value = ""
      this.sendTypingStatus(false)
    } catch (error) {
      console.error("Failed to send message:", error)
    }
  }

  onInput() {
    this.sendTypingStatus(true)

    if (this.typingTimeout) clearTimeout(this.typingTimeout)
    this.typingTimeout = setTimeout(() => {
      this.sendTypingStatus(false)
    }, 3000)
  }

  onKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      this.sendMessage(event)
    }
  }

  sendTypingStatus(isTyping) {
    if (this.subscription) {
      this.subscription.perform("typing", { is_typing: isTyping })
    }
  }

  renderMessages(messages) {
    if (!this.hasMessagesTarget) return
    this.messagesTarget.innerHTML = ""
    messages.forEach(msg => this.appendMessage(msg))
  }

  appendMessage(message) {
    if (!this.hasMessagesTarget) return

    const div = document.createElement("div")
    div.className = "kazhat-message"
    div.dataset.messageId = message.id

    const isOwn = message.sender_id === this.userIdValue
    div.classList.add(isOwn ? "kazhat-message-own" : "kazhat-message-other")

    div.innerHTML = `
      <div class="kazhat-message-sender">${this.escapeHtml(message.sender_name)}</div>
      <div class="kazhat-message-body">${this.escapeHtml(message.body)}</div>
      <div class="kazhat-message-time">${this.formatTime(message.created_at)}</div>
    `

    this.messagesTarget.appendChild(div)
  }

  handleTypingIndicator(data) {
    if (!this.hasTypingIndicatorTarget) return
    if (data.user_id === this.userIdValue) return

    if (data.is_typing) {
      this.typingIndicatorTarget.textContent = `${data.user_name} is typing...`
      this.typingIndicatorTarget.style.display = "block"
    } else {
      this.typingIndicatorTarget.style.display = "none"
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  formatTime(isoString) {
    const date = new Date(isoString)
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

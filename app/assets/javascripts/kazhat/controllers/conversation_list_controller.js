import { Controller } from "@hotwired/stimulus"
import { api } from "../lib/api"

export default class extends Controller {
  static targets = ["list", "searchInput"]

  connect() {
    this.loadConversations()
  }

  async loadConversations() {
    try {
      const data = await api.get("/conversations")
      if (data.conversations) {
        this.renderConversations(data.conversations)
      }
    } catch (error) {
      console.error("Failed to load conversations:", error)
    }
  }

  renderConversations(conversations) {
    if (!this.hasListTarget) return

    this.listTarget.innerHTML = ""
    conversations.forEach(conv => {
      const item = document.createElement("div")
      item.className = "kazhat-conversation-item"
      item.dataset.conversationId = conv.id
      item.dataset.action = "click->kazhat--conversation-list#selectConversation"

      const unreadBadge = conv.unread_count > 0
        ? `<span class="kazhat-unread-badge">${conv.unread_count}</span>`
        : ""

      const lastMessage = conv.last_message
        ? `<div class="kazhat-conversation-preview">${this.escapeHtml(conv.last_message.body)}</div>`
        : ""

      item.innerHTML = `
        <div class="kazhat-conversation-name">${this.escapeHtml(conv.name)}${unreadBadge}</div>
        ${lastMessage}
      `

      this.listTarget.appendChild(item)
    })
  }

  selectConversation(event) {
    const conversationId = event.currentTarget.dataset.conversationId
    this.dispatch("selected", { detail: { conversationId } })

    // Highlight selected
    this.listTarget.querySelectorAll(".kazhat-conversation-item").forEach(el => {
      el.classList.remove("kazhat-selected")
    })
    event.currentTarget.classList.add("kazhat-selected")
  }

  search() {
    if (!this.hasSearchInputTarget || !this.hasListTarget) return

    const query = this.searchInputTarget.value.toLowerCase()
    this.listTarget.querySelectorAll(".kazhat-conversation-item").forEach(el => {
      const name = el.querySelector(".kazhat-conversation-name")?.textContent.toLowerCase() || ""
      el.style.display = name.includes(query) ? "" : "none"
    })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

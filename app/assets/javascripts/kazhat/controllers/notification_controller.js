import { Controller } from "@hotwired/stimulus"
import { createSubscription } from "../lib/cable"
import { callState } from "../lib/call_state"

export default class extends Controller {
  static values = {
    userId: Number
  }

  connect() {
    if (!this.userIdValue) return

    this.subscription = createSubscription("NotificationChannel", {}, {
      received: (data) => this.handleNotification(data)
    })
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  handleNotification(data) {
    switch (data.type) {
      case "incoming_call":
        this.handleIncomingCall(data.call)
        break
      case "new_message":
        this.handleNewMessage(data.message)
        break
    }
  }

  handleIncomingCall(call) {
    // Don't show if already in a call
    if (callState.get().callState !== "idle") return

    callState.set({ callState: "ringing_incoming" })

    this.dispatch("incomingCall", { detail: { call } })

    // Create incoming call UI
    const container = document.createElement("div")
    container.className = "kazhat-incoming-call"
    container.innerHTML = `
      <div class="kazhat-incoming-call-info">
        <strong>${this.escapeHtml(call.initiator.name)}</strong>
        <span>${call.call_type === "video" ? "Video Call" : "Audio Call"}</span>
      </div>
      <div class="kazhat-incoming-call-actions">
        <button class="kazhat-btn kazhat-btn-accept" data-call-id="${call.id}">Accept</button>
        <button class="kazhat-btn kazhat-btn-decline" data-call-id="${call.id}">Decline</button>
      </div>
    `

    const acceptBtn = container.querySelector(".kazhat-btn-accept")
    const declineBtn = container.querySelector(".kazhat-btn-decline")

    acceptBtn.addEventListener("click", () => {
      callState.set({ callState: "connecting", callId: call.id })
      container.remove()
      this.dispatch("callAccepted", { detail: { callId: call.id } })
    })

    declineBtn.addEventListener("click", () => {
      callState.set({ callState: "idle" })
      container.remove()
      this.dispatch("callDeclined", { detail: { callId: call.id } })
    })

    this.element.appendChild(container)

    // Auto-dismiss after 30 seconds
    setTimeout(() => {
      if (container.parentNode) {
        container.remove()
        if (callState.get().callState === "ringing_incoming") {
          callState.set({ callState: "idle" })
        }
      }
    }, 30000)
  }

  handleNewMessage(message) {
    this.dispatch("newMessage", { detail: { message } })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

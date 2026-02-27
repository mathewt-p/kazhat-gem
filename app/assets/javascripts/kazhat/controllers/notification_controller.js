import { Controller } from "@hotwired/stimulus"
import { createSubscription } from "kazhat/lib/cable"
import { callState } from "kazhat/lib/call_state"
import { injectCallPopup } from "kazhat/lib/call_popup"

export default class extends Controller {
  static values = {
    userId: Number
  }

  connect() {
    if (!this.userIdValue) {
      console.warn("[Kazhat] Notification controller: no userId, skipping")
      return
    }

    console.log("[Kazhat] Notification controller connected, userId:", this.userIdValue)
    this.subscription = createSubscription("NotificationChannel", {}, {
      connected: () => console.log("[Kazhat] NotificationChannel connected"),
      received: (data) => this.handleNotification(data),
      disconnected: () => console.log("[Kazhat] NotificationChannel disconnected")
    })
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  handleNotification(data) {
    console.log("[Kazhat] Notification received:", data.type, data)
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
    if (callState.get().callState !== "idle") {
      console.log("[Kazhat] Ignoring incoming call, already in a call")
      return
    }

    console.log("[Kazhat] Incoming call:", call.id, "from:", call.initiator?.name, "type:", call.call_type)
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
      console.log("[Kazhat] Accepting call:", call.id)
      callState.set({ callState: "connecting", callId: call.id })
      container.remove()
      injectCallPopup(call.id, call.call_type || "video")
      this.dispatch("callAccepted", { detail: { callId: call.id } })
    })

    declineBtn.addEventListener("click", () => {
      console.log("[Kazhat] Declining call:", call.id)
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

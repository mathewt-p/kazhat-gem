import { Controller } from "@hotwired/stimulus"
import { api } from "kazhat/lib/api"
import { callState } from "kazhat/lib/call_state"
import { injectCallPopup } from "kazhat/lib/call_popup"

export default class extends Controller {
  static values = {
    userId: Number,
    conversationId: Number,
    callType: String
  }

  async call(event) {
    event.preventDefault()

    if (callState.get().callState !== "idle") {
      console.warn("[Kazhat] Already in a call")
      return
    }

    try {
      callState.set({ callState: "connecting" })

      const params = { call_type: this.callTypeValue || "video" }
      if (this.hasConversationIdValue && this.conversationIdValue) {
        params.conversation_id = this.conversationIdValue
      } else {
        params.user_id = this.userIdValue
      }

      console.log("[Kazhat] Creating call via API:", params)
      const response = await api.post("/calls", params)
      console.log("[Kazhat] Call created:", response)

      const callId = response.call.id
      const callType = this.callTypeValue || "video"
      callState.set({ callId })

      console.log("[Kazhat] Injecting call popup, callId:", callId, "callType:", callType)
      injectCallPopup(callId, callType)
    } catch (error) {
      console.error("[Kazhat] Failed to initiate call:", error)
      callState.set({ callState: "idle" })
    }
  }
}

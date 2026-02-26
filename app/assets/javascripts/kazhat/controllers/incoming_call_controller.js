import { Controller } from "@hotwired/stimulus"
import { callState } from "../lib/call_state"
import { api } from "../lib/api"

export default class extends Controller {
  static targets = ["container", "callerName", "callType"]

  static values = {
    callId: Number,
    callType: String,
    callerName: String
  }

  connect() {
    this.show()
  }

  show() {
    if (this.hasCallerNameTarget) {
      this.callerNameTarget.textContent = this.callerNameValue
    }
    if (this.hasCallTypeTarget) {
      this.callTypeTarget.textContent = this.callTypeValue === "video" ? "Video Call" : "Audio Call"
    }
    if (this.hasContainerTarget) {
      this.containerTarget.style.display = "block"
    }
  }

  accept() {
    callState.set({
      callState: "connecting",
      callId: this.callIdValue
    })

    this.hide()
    this.dispatch("accepted", { detail: { callId: this.callIdValue } })
  }

  decline() {
    this.hide()
    this.dispatch("declined", { detail: { callId: this.callIdValue } })
  }

  hide() {
    if (this.hasContainerTarget) {
      this.containerTarget.style.display = "none"
    }
  }
}

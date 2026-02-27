import { Controller } from "@hotwired/stimulus"
import { callState } from "kazhat/lib/call_state"

export default class extends Controller {
  static targets = ["display"]

  connect() {
    this.startTime = null
    this.timerInterval = null
    this.unsubscribe = callState.subscribe((state) => this.handleStateChange(state))
  }

  disconnect() {
    if (this.unsubscribe) this.unsubscribe()
    this.stopTimer()
  }

  handleStateChange(state) {
    if (state.callState === "connected" && !this.timerInterval) {
      this.startTimer()
    } else if (state.callState === "idle" || state.callState === "ended") {
      this.stopTimer()
    }
  }

  startTimer() {
    this.startTime = Date.now()
    this.timerInterval = setInterval(() => this.updateDisplay(), 1000)
    this.updateDisplay()
  }

  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }
  }

  updateDisplay() {
    if (!this.hasDisplayTarget || !this.startTime) return

    const elapsed = Math.floor((Date.now() - this.startTime) / 1000)
    const hours = Math.floor(elapsed / 3600)
    const minutes = Math.floor((elapsed % 3600) / 60)
    const seconds = elapsed % 60

    if (hours > 0) {
      this.displayTarget.textContent = `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
    } else {
      this.displayTarget.textContent = `${minutes}:${String(seconds).padStart(2, "0")}`
    }
  }
}

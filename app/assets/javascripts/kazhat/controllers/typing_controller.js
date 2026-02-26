import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator"]

  static values = {
    userId: Number
  }

  connect() {
    this.typingUsers = new Map()
  }

  show({ detail: { userId, userName } }) {
    if (userId === this.userIdValue) return

    this.typingUsers.set(userId, userName)
    this.updateDisplay()

    // Auto-clear after 5 seconds
    setTimeout(() => {
      this.typingUsers.delete(userId)
      this.updateDisplay()
    }, 5000)
  }

  hide({ detail: { userId } }) {
    this.typingUsers.delete(userId)
    this.updateDisplay()
  }

  updateDisplay() {
    if (!this.hasIndicatorTarget) return

    if (this.typingUsers.size === 0) {
      this.indicatorTarget.style.display = "none"
      return
    }

    const names = Array.from(this.typingUsers.values())
    let text

    if (names.length === 1) {
      text = `${names[0]} is typing...`
    } else if (names.length === 2) {
      text = `${names[0]} and ${names[1]} are typing...`
    } else {
      text = "Several people are typing..."
    }

    this.indicatorTarget.textContent = text
    this.indicatorTarget.style.display = "block"
  }
}

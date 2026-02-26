import { Controller } from "@hotwired/stimulus"
import { callState } from "../lib/call_state"

export default class extends Controller {
  static targets = ["grid", "localVideo"]

  connect() {
    this.videoElements = new Map()
    this.unsubscribe = callState.subscribe((state) => this.showLocalVideo(state))
  }

  disconnect() {
    if (this.unsubscribe) this.unsubscribe()
    this.videoElements.clear()
  }

  showLocalVideo(state) {
    if (this.hasLocalVideoTarget && state.localStream) {
      this.localVideoTarget.srcObject = state.localStream
      this.localVideoTarget.muted = true
    }
  }

  addRemoteStream({ detail: { peerId, participant, stream } }) {
    if (this.videoElements.has(peerId)) {
      // Update existing video element
      this.videoElements.get(peerId).srcObject = stream
      return
    }

    const container = document.createElement("div")
    container.className = "kazhat-video-container"
    container.dataset.peerId = peerId

    const video = document.createElement("video")
    video.autoplay = true
    video.playsInline = true
    video.srcObject = stream

    const nameLabel = document.createElement("div")
    nameLabel.className = "kazhat-video-name"
    nameLabel.textContent = participant.name || "Participant"

    container.appendChild(video)
    container.appendChild(nameLabel)

    if (this.hasGridTarget) {
      this.gridTarget.appendChild(container)
    }

    this.videoElements.set(peerId, video)
    this.updateGridLayout()
  }

  removeParticipant({ detail: { participantId } }) {
    for (const [peerId, video] of this.videoElements.entries()) {
      const container = video.closest(".kazhat-video-container")
      if (container && container.dataset.peerId == participantId) {
        video.srcObject = null
        container.remove()
        this.videoElements.delete(peerId)
      }
    }
    this.updateGridLayout()
  }

  updateGridLayout() {
    if (!this.hasGridTarget) return

    const count = this.videoElements.size + 1 // +1 for local video
    this.gridTarget.dataset.participantCount = count

    // CSS grid columns based on participant count
    if (count <= 2) {
      this.gridTarget.style.gridTemplateColumns = "1fr"
    } else if (count <= 4) {
      this.gridTarget.style.gridTemplateColumns = "1fr 1fr"
    } else {
      this.gridTarget.style.gridTemplateColumns = "1fr 1fr 1fr"
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import { callState } from "../lib/call_state"
import { replaceVideoTrack } from "../lib/webrtc"

export default class extends Controller {
  static targets = ["muteBtn", "videoBtn", "screenBtn"]

  connect() {
    this.unsubscribe = callState.subscribe((state) => this.updateUI(state))
    this.bindKeyboardShortcuts()
  }

  disconnect() {
    if (this.unsubscribe) this.unsubscribe()
    this.unbindKeyboardShortcuts()
  }

  toggleMute() {
    const state = callState.get()
    const enabled = !state.audioEnabled

    if (state.localStream) {
      state.localStream.getAudioTracks().forEach(track => {
        track.enabled = enabled
      })
    }

    callState.set({ audioEnabled: enabled })
  }

  toggleVideo() {
    const state = callState.get()
    const enabled = !state.videoEnabled

    if (state.localStream) {
      state.localStream.getVideoTracks().forEach(track => {
        track.enabled = enabled
      })
    }

    callState.set({ videoEnabled: enabled })
  }

  async toggleScreenShare() {
    const state = callState.get()

    if (state.screenSharing) {
      await this.stopScreenShare()
    } else {
      await this.startScreenShare()
    }
  }

  async startScreenShare() {
    try {
      const screenStream = await navigator.mediaDevices.getDisplayMedia({
        video: { cursor: "always" },
        audio: false
      })

      const screenTrack = screenStream.getVideoTracks()[0]

      // Browser stop-sharing handler
      screenTrack.onended = () => {
        this.stopScreenShare()
      }

      // Replace video track on all peer connections
      for (const [, { pc }] of callState.get().remotePeers) {
        await replaceVideoTrack(pc, screenTrack)
      }

      callState.set({ screenSharing: true, screenStream })
    } catch (error) {
      console.error("Screen share failed:", error)
    }
  }

  async stopScreenShare() {
    const state = callState.get()

    if (state.screenStream) {
      state.screenStream.getTracks().forEach(track => track.stop())
    }

    // Revert to camera track
    const cameraTrack = state.localStream?.getVideoTracks()[0]
    if (cameraTrack) {
      for (const [, { pc }] of state.remotePeers) {
        await replaceVideoTrack(pc, cameraTrack)
      }
    }

    callState.set({ screenSharing: false, screenStream: null })
  }

  hangup() {
    this.dispatch("hangup")
    callState.reset()
  }

  updateUI(state) {
    if (this.hasMuteBtnTarget) {
      this.muteBtnTarget.classList.toggle("kazhat-active", !state.audioEnabled)
      this.muteBtnTarget.textContent = state.audioEnabled ? "Mute" : "Unmute"
    }

    if (this.hasVideoBtnTarget) {
      this.videoBtnTarget.classList.toggle("kazhat-active", !state.videoEnabled)
      this.videoBtnTarget.textContent = state.videoEnabled ? "Stop Video" : "Start Video"
    }

    if (this.hasScreenBtnTarget) {
      this.screenBtnTarget.classList.toggle("kazhat-active", state.screenSharing)
      this.screenBtnTarget.textContent = state.screenSharing ? "Stop Share" : "Share Screen"
    }
  }

  bindKeyboardShortcuts() {
    this._keyHandler = (e) => {
      if (callState.get().callState !== "connected") return

      if (e.key === "m" && e.ctrlKey) {
        e.preventDefault()
        this.toggleMute()
      } else if (e.key === "e" && e.ctrlKey) {
        e.preventDefault()
        this.toggleVideo()
      } else if (e.key === "s" && e.ctrlKey && e.shiftKey) {
        e.preventDefault()
        this.toggleScreenShare()
      }
    }
    document.addEventListener("keydown", this._keyHandler)
  }

  unbindKeyboardShortcuts() {
    if (this._keyHandler) {
      document.removeEventListener("keydown", this._keyHandler)
    }
  }
}

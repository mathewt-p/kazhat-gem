// Dynamically injects the call popup DOM element, which triggers
// the kazhat--call Stimulus controller to initialize WebRTC.
export function injectCallPopup(callId, callType = "video") {
  removeCallPopup()

  const userId = document.querySelector('meta[name="kazhat-user-id"]')?.content || ""

  const popup = document.createElement("div")
  popup.className = "kazhat-popup"
  popup.id = "kazhat-call-popup"

  // Must use setAttribute for Stimulus namespaced attributes (double-hyphen --).
  // The dataset API converts camelCase to single hyphens, which breaks
  // Stimulus identifiers like "kazhat--call".
  popup.setAttribute("data-controller",
    "kazhat--call-popup kazhat--call kazhat--call-controls kazhat--video-grid kazhat--call-timer")
  popup.setAttribute("data-kazhat--call-popup-target", "popup")
  popup.setAttribute("data-kazhat--call-call-id-value", callId)
  popup.setAttribute("data-kazhat--call-user-id-value", userId)
  popup.setAttribute("data-kazhat--call-call-type-value", callType)
  popup.setAttribute("data-action",
    "kazhat--call:addRemoteStream->kazhat--video-grid#addRemoteStream kazhat--call:removeParticipant->kazhat--video-grid#removeParticipant")

  popup.innerHTML = `
    <div class="kazhat-popup-header" data-action="mousedown->kazhat--call-popup#startDrag">
      <span class="kazhat-call-timer" data-kazhat--call-timer-target="display">0:00</span>
      <div class="kazhat-popup-header-buttons">
        <button data-action="click->kazhat--call-popup#toggleMinimize">_</button>
        <button data-action="click->kazhat--call-popup#toggleFullscreen">[]</button>
      </div>
    </div>
    <div class="kazhat-video-grid" data-kazhat--video-grid-target="grid">
      <div class="kazhat-local-video">
        <video data-kazhat--video-grid-target="localVideo" autoplay playsinline muted></video>
      </div>
    </div>
    <div class="kazhat-call-controls">
      <button class="kazhat-btn-control" data-kazhat--call-controls-target="muteBtn"
              data-action="click->kazhat--call-controls#toggleMute">Mute</button>
      <button class="kazhat-btn-control" data-kazhat--call-controls-target="videoBtn"
              data-action="click->kazhat--call-controls#toggleVideo">Stop Video</button>
      <button class="kazhat-btn-control" data-kazhat--call-controls-target="screenBtn"
              data-action="click->kazhat--call-controls#toggleScreenShare">Share Screen</button>
      <button class="kazhat-btn-hangup"
              data-action="click->kazhat--call-controls#hangup">Hang Up</button>
    </div>
  `

  const container = document.getElementById("kazhat-container") || document.body
  container.appendChild(popup)
}

// Remove the call popup from the DOM, triggering Stimulus disconnect on all controllers.
export function removeCallPopup() {
  const existing = document.getElementById("kazhat-call-popup")
  if (existing) existing.remove()
}

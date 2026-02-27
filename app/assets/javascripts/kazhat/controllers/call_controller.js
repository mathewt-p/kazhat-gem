import { Controller } from "@hotwired/stimulus"
import { callState } from "kazhat/lib/call_state"
import { createSubscription } from "kazhat/lib/cable"
import {
  getMediaConstraints,
  createPeerConnection,
  createOffer,
  handleOffer,
  handleAnswer,
  handleIceCandidate,
  replaceVideoTrack
} from "kazhat/lib/webrtc"
import { removeCallPopup } from "kazhat/lib/call_popup"

export default class extends Controller {
  static values = {
    callId: String,
    userId: Number,
    callType: { type: String, default: "video" }
  }

  static targets = ["popup", "videoGrid"]

  async connect() {
    this._renegotiationReady = true
    this._messageQueue = Promise.resolve()
    console.log("[Kazhat] Call controller connected", {
      callId: this.callIdValue,
      userId: this.userIdValue,
      callType: this.callTypeValue
    })
    await this.initializeCall()
  }

  disconnect() {
    console.log("[Kazhat] Call controller disconnected")
    this.cleanup()
  }

  async initializeCall() {
    try {
      const isVideo = this.callTypeValue === "video"
      // Always acquire video so the track/sender exists from the start.
      // For audio-only calls we just disable the video track — toggling
      // it on later is a simple track.enabled flip with no renegotiation.
      const constraints = getMediaConstraints(2, true)
      console.log("[Kazhat] Requesting media:", constraints)
      const stream = await navigator.mediaDevices.getUserMedia(constraints)
      console.log("[Kazhat] Got local stream, tracks:", stream.getTracks().map(t => `${t.kind}:${t.readyState}`))

      if (!isVideo) {
        stream.getVideoTracks().forEach(track => { track.enabled = false })
      }

      callState.set({
        localStream: stream,
        callId: this.callIdValue,
        callState: "connecting",
        videoEnabled: isVideo
      })

      console.log("[Kazhat] Creating ActionCable subscription for call:", this.callIdValue)
      this.subscription = createSubscription("CallChannel",
        { call_id: this.callIdValue },
        {
          connected: () => this.handleConnected(),
          received: (data) => this.enqueueMessage(data),
          disconnected: () => this.handleDisconnected()
        }
      )
    } catch (error) {
      console.error("[Kazhat] Failed to initialize call:", error)
      callState.set({ callState: "idle" })
      this.dispatch("error", { detail: { message: "Could not access camera/microphone" } })
    }
  }

  handleConnected() {
    console.log("[Kazhat] ActionCable connected, sending answer")
    this.subscription.perform("answer", {})
    callState.set({ callState: "connected" })
  }

  // Serialize async message processing to prevent race conditions
  // (e.g., ICE candidates arriving while offer is being processed)
  enqueueMessage(data) {
    this._messageQueue = this._messageQueue
      .then(() => this.handleMessage(data))
      .catch(err => console.error("[Kazhat] Error processing message:", err))
  }

  async handleMessage(data) {
    console.log("[Kazhat] Received:", data.type, data.type === "signal" ? data.signal?.type : "")

    switch (data.type) {
      case "existing_participants":
        console.log("[Kazhat] Existing participants:", data.participants.length)
        for (const participant of data.participants) {
          await this.connectToParticipant(participant, true)
        }
        break

      case "participant_joined":
        console.log("[Kazhat] Participant joined:", data.participant?.id)
        callState.set({ participants: data.participants })
        break

      case "signal":
        // Skip own signals (broadcast goes to all subscribers)
        if (data.from_user_id === this.userIdValue) return
        // Only handle signals targeted at us
        if (data.target_user_id && data.target_user_id !== this.userIdValue) return
        await this.handleSignal(data)
        break

      case "participant_left":
        console.log("[Kazhat] Participant left:", data.participant_id)
        this.removeParticipant(data.participant_id)
        callState.set({ participants: data.participants || [] })
        // Auto-end call when all remote peers have left
        if (callState.get().remotePeers.size === 0 &&
            callState.get().callState === "connected") {
          console.log("[Kazhat] All peers left, ending call")
          callState.reset()
          removeCallPopup()
        }
        break

      case "participant_rejected":
        this.removeParticipant(data.participant_id)
        break

      case "error":
        console.error("[Kazhat] Server error:", data.message)
        this.dispatch("error", { detail: { message: data.message } })
        break
    }
  }

  async connectToParticipant(participant, shouldCreateOffer) {
    const userId = participant.id
    if (userId === this.userIdValue) return
    if (callState.get().remotePeers.has(userId)) return

    console.log("[Kazhat] Connecting to participant:", userId, participant.name)

    const pc = createPeerConnection(callState.get().localStream, {
      onTrack: (stream) => {
        console.log("[Kazhat] Got remote track from:", userId, "tracks:", stream.getTracks().map(t => `${t.kind}:${t.readyState}`))
        this.dispatch("addRemoteStream", {
          detail: { peerId: userId, participant, stream }
        })
      },
      onIceCandidate: (candidate) => {
        this.subscription.perform("signal", {
          target_user_id: userId,
          signal: { type: "ice-candidate", candidate }
        })
      },
      onConnectionStateChange: (state) => {
        console.log("[Kazhat] Connection state with", userId, ":", state)
        if (state === "failed" || state === "disconnected") {
          this.handleConnectionFailure(userId, participant)
        }
      }
    })

    callState.get().remotePeers.set(userId, { pc, participant })

    if (shouldCreateOffer) {
      if (!this._renegotiationReady) return
      this._renegotiationReady = false

      try {
        console.log("[Kazhat] Creating offer for:", userId)
        const offer = await createOffer(pc)
        console.log("[Kazhat] Sending offer to:", userId)
        this.subscription.perform("signal", {
          target_user_id: userId,
          signal: { type: "offer", offer }
        })
      } finally {
        this._renegotiationReady = true
      }
    }
  }

  async handleSignal(data) {
    const { from_user_id, signal } = data
    let peerData = callState.get().remotePeers.get(from_user_id)

    switch (signal.type) {
      case "offer":
        console.log("[Kazhat] Received offer from:", from_user_id, "existing peer:", !!peerData)
        if (!peerData) {
          const knownParticipant = (callState.get().participants || []).find(p => p.id === from_user_id) || { id: from_user_id }
          const pc = createPeerConnection(callState.get().localStream, {
            onTrack: (stream) => {
              console.log("[Kazhat] Got remote track from:", from_user_id, "tracks:", stream.getTracks().map(t => `${t.kind}:${t.readyState}`))
              this.dispatch("addRemoteStream", {
                detail: { peerId: from_user_id, participant: knownParticipant, stream }
              })
            },
            onIceCandidate: (candidate) => {
              this.subscription.perform("signal", {
                target_user_id: from_user_id,
                signal: { type: "ice-candidate", candidate }
              })
            },
            onConnectionStateChange: (state) => {
              console.log("[Kazhat] Connection state with", from_user_id, ":", state)
              if (state === "failed" || state === "disconnected") {
                this.handleConnectionFailure(from_user_id, knownParticipant)
              }
            }
          })
          peerData = { pc, participant: knownParticipant }
          callState.get().remotePeers.set(from_user_id, peerData)
        }

        const answer = await handleOffer(peerData.pc, signal.offer)
        if (answer) {
          console.log("[Kazhat] Sending answer to:", from_user_id)
          this.subscription.perform("signal", {
            target_user_id: from_user_id,
            signal: { type: "answer", answer }
          })
        } else {
          console.warn("[Kazhat] handleOffer returned null (signalingState issue)")
        }
        break

      case "answer":
        console.log("[Kazhat] Received answer from:", from_user_id, "existing peer:", !!peerData)
        if (peerData) {
          await handleAnswer(peerData.pc, signal.answer)
          console.log("[Kazhat] Answer processed, signalingState:", peerData.pc.signalingState)
        }
        break

      case "ice-candidate":
        if (peerData) {
          await handleIceCandidate(peerData.pc, signal.candidate)
        }
        break
    }
  }

  removeParticipant(userId) {
    const peerData = callState.get().remotePeers.get(userId)
    if (peerData) {
      peerData.pc.close()
      callState.get().remotePeers.delete(userId)
      this.dispatch("removeParticipant", { detail: { participantId: userId } })
    }
  }

  handleConnectionFailure(userId, participant) {
    console.warn(`[Kazhat] Connection to peer ${userId} failed`)
    this.removeParticipant(userId)
  }

  handleDisconnected() {
    console.warn("[Kazhat] Disconnected from call channel")
  }

  cleanup() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    callState.reset()
  }
}

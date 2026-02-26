import { Controller } from "@hotwired/stimulus"
import { callState } from "../lib/call_state"
import { createSubscription } from "../lib/cable"
import {
  getMediaConstraints,
  createPeerConnection,
  createOffer,
  handleOffer,
  handleAnswer,
  handleIceCandidate,
  replaceVideoTrack
} from "../lib/webrtc"

export default class extends Controller {
  static values = {
    callId: String,
    userId: Number
  }

  static targets = ["popup", "videoGrid"]

  async connect() {
    this._renegotiationReady = true
    await this.initializeCall()
  }

  disconnect() {
    this.cleanup()
  }

  async initializeCall() {
    try {
      const constraints = getMediaConstraints(2)
      const stream = await navigator.mediaDevices.getUserMedia(constraints)

      callState.set({
        localStream: stream,
        callId: this.callIdValue,
        callState: "connecting"
      })

      this.subscription = createSubscription("CallChannel",
        { call_id: this.callIdValue },
        {
          connected: () => this.handleConnected(),
          received: (data) => this.handleMessage(data),
          disconnected: () => this.handleDisconnected()
        }
      )
    } catch (error) {
      console.error("Failed to initialize call:", error)
      callState.set({ callState: "idle" })
      this.dispatch("error", { detail: { message: "Could not access camera/microphone" } })
    }
  }

  handleConnected() {
    this.subscription.perform("answer", {})
    callState.set({ callState: "connected" })
  }

  async handleMessage(data) {
    switch (data.type) {
      case "existing_participants":
        for (const participant of data.participants) {
          await this.connectToParticipant(participant, true)
        }
        break

      case "participant_joined":
        callState.set({ participants: data.participants })
        break

      case "signal":
        // Only handle signals targeted at us
        if (data.target_peer_id && data.target_peer_id !== this._myPeerId) return
        await this.handleSignal(data)
        break

      case "participant_left":
        this.removeParticipant(data.participant_id)
        callState.set({ participants: data.participants || [] })
        break

      case "participant_rejected":
        this.removeParticipant(data.participant_id)
        break

      case "error":
        this.dispatch("error", { detail: { message: data.message } })
        break
    }
  }

  async connectToParticipant(participant, shouldCreateOffer) {
    const peerId = participant.peer_id
    if (callState.get().remotePeers.has(peerId)) return

    const pc = createPeerConnection(callState.get().localStream, {
      onTrack: (stream) => {
        this.dispatch("addRemoteStream", {
          detail: { peerId, participant, stream }
        })
      },
      onIceCandidate: (candidate) => {
        this.subscription.perform("signal", {
          target_peer_id: peerId,
          signal: { type: "ice-candidate", candidate }
        })
      },
      onConnectionStateChange: (state) => {
        if (state === "failed" || state === "disconnected") {
          this.handleConnectionFailure(peerId, participant)
        }
      }
    })

    callState.get().remotePeers.set(peerId, { pc, participant })
    this._myPeerId = this._myPeerId || participant.peer_id

    if (shouldCreateOffer) {
      if (!this._renegotiationReady) return
      this._renegotiationReady = false

      try {
        const offer = await createOffer(pc)
        this.subscription.perform("signal", {
          target_peer_id: peerId,
          signal: { type: "offer", offer }
        })
      } finally {
        this._renegotiationReady = true
      }
    }
  }

  async handleSignal(data) {
    const { from_peer_id, signal } = data
    let peerData = callState.get().remotePeers.get(from_peer_id)

    switch (signal.type) {
      case "offer":
        if (!peerData) {
          const pc = createPeerConnection(callState.get().localStream, {
            onTrack: (stream) => this.dispatch("addRemoteStream", {
              detail: { peerId: from_peer_id, participant: { peer_id: from_peer_id }, stream }
            }),
            onIceCandidate: (candidate) => {
              this.subscription.perform("signal", {
                target_peer_id: from_peer_id,
                signal: { type: "ice-candidate", candidate }
              })
            },
            onConnectionStateChange: (state) => {
              if (state === "failed" || state === "disconnected") {
                this.handleConnectionFailure(from_peer_id, { peer_id: from_peer_id })
              }
            }
          })
          peerData = { pc }
          callState.get().remotePeers.set(from_peer_id, peerData)
        }

        const answer = await handleOffer(peerData.pc, signal.offer)
        if (answer) {
          this.subscription.perform("signal", {
            target_peer_id: from_peer_id,
            signal: { type: "answer", answer }
          })
        }
        break

      case "answer":
        if (peerData) {
          await handleAnswer(peerData.pc, signal.answer)
        }
        break

      case "ice-candidate":
        if (peerData) {
          await handleIceCandidate(peerData.pc, signal.candidate)
        }
        break
    }
  }

  removeParticipant(participantId) {
    for (const [peerId, data] of callState.get().remotePeers.entries()) {
      if (data.participant?.id === participantId) {
        data.pc.close()
        callState.get().remotePeers.delete(peerId)
        this.dispatch("removeParticipant", { detail: { participantId } })
      }
    }
  }

  handleConnectionFailure(peerId, participant) {
    console.warn(`Connection to peer ${peerId} failed`)
    // Remove the failed peer
    const peerData = callState.get().remotePeers.get(peerId)
    if (peerData) {
      peerData.pc.close()
      callState.get().remotePeers.delete(peerId)
      this.dispatch("removeParticipant", { detail: { participantId: participant.id } })
    }
  }

  handleDisconnected() {
    console.warn("Disconnected from call channel")
  }

  cleanup() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    callState.reset()
  }
}

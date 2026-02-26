const state = {
  callState: "idle",       // idle | connecting | ringing_outgoing | ringing_incoming | connected | ended
  callId: null,
  conversationId: null,
  localStream: null,
  remotePeers: new Map(),  // Map<peerId, { pc, stream, participant }>
  audioEnabled: true,
  videoEnabled: true,
  screenSharing: false,
  screenStream: null,
  popupPosition: { bottom: 20, right: 20 },
  isFullscreen: false,
  isMinimized: false,
  participants: []
}

const listeners = new Set()

export const callState = {
  get: () => state,

  set: (patch) => {
    Object.assign(state, patch)
    listeners.forEach(fn => fn(state))
  },

  subscribe: (fn) => {
    listeners.add(fn)
    fn(state)
    return () => listeners.delete(fn)
  },

  reset: () => {
    if (state.localStream) {
      state.localStream.getTracks().forEach(track => track.stop())
    }
    if (state.screenStream) {
      state.screenStream.getTracks().forEach(track => track.stop())
    }

    state.remotePeers.forEach(({ pc }) => pc.close())

    Object.assign(state, {
      callState: "idle",
      callId: null,
      conversationId: null,
      localStream: null,
      remotePeers: new Map(),
      audioEnabled: true,
      videoEnabled: true,
      screenSharing: false,
      screenStream: null,
      participants: []
    })

    listeners.forEach(fn => fn(state))
  }
}

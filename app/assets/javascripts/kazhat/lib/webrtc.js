export function getMediaConstraints(participantCount) {
  const quality = window.kazhatConfig?.videoQuality || {
    2: { width: 1280, height: 720, frameRate: 30 },
    3: { width: 960, height: 540, frameRate: 24 },
    4: { width: 640, height: 480, frameRate: 20 },
    5: { width: 640, height: 480, frameRate: 20 }
  }

  const level = Math.min(participantCount, 5)

  return {
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true
    },
    video: quality[level] || quality[2]
  }
}

export function getTurnServers() {
  try {
    const metaTag = document.querySelector('meta[name="kazhat-turn-servers"]')
    return metaTag ? JSON.parse(metaTag.content) : [{ urls: "stun:stun.l.google.com:19302" }]
  } catch (e) {
    console.error("Failed to parse TURN servers:", e)
    return [{ urls: "stun:stun.l.google.com:19302" }]
  }
}

export function createPeerConnection(localStream, callbacks = {}) {
  const config = {
    iceServers: getTurnServers()
  }

  const pc = new RTCPeerConnection(config)

  if (localStream) {
    localStream.getTracks().forEach(track => {
      pc.addTrack(track, localStream)
    })
  }

  pc.ontrack = (event) => {
    if (callbacks.onTrack) {
      // Fallback: construct stream from receivers if event.streams is empty
      const stream = event.streams[0] || syncRemoteStream(pc)
      callbacks.onTrack(stream)
    }
  }

  pc.onicecandidate = (event) => {
    if (event.candidate && callbacks.onIceCandidate) {
      callbacks.onIceCandidate(event.candidate)
    }
  }

  pc.onconnectionstatechange = () => {
    if (callbacks.onConnectionStateChange) {
      callbacks.onConnectionStateChange(pc.connectionState)
    }
  }

  pc.oniceconnectionstatechange = () => {
    if (callbacks.onIceConnectionStateChange) {
      callbacks.onIceConnectionStateChange(pc.iceConnectionState)
    }
  }

  return pc
}

// Fallback: manually construct MediaStream from receivers when ontrack doesn't provide streams
export function syncRemoteStream(pc) {
  const stream = new MediaStream()
  pc.getReceivers().forEach(receiver => {
    if (receiver.track) {
      stream.addTrack(receiver.track)
    }
  })
  return stream
}

export async function createOffer(pc) {
  const offer = await pc.createOffer()
  await pc.setLocalDescription(offer)
  return offer
}

export async function createAnswer(pc) {
  const answer = await pc.createAnswer()
  await pc.setLocalDescription(answer)
  return answer
}

export async function handleOffer(pc, offer) {
  // Renegotiation guard: check signalingState before setting remote description
  if (pc.signalingState !== "stable") {
    console.warn("Skipping offer: signalingState is", pc.signalingState)
    return null
  }
  await pc.setRemoteDescription(new RTCSessionDescription(offer))
  return await createAnswer(pc)
}

export async function handleAnswer(pc, answer) {
  if (pc.signalingState !== "have-local-offer") {
    console.warn("Skipping answer: signalingState is", pc.signalingState)
    return
  }
  await pc.setRemoteDescription(new RTCSessionDescription(answer))
}

export async function handleIceCandidate(pc, candidate) {
  if (candidate && pc.remoteDescription) {
    await pc.addIceCandidate(new RTCIceCandidate(candidate))
  }
}

// Screen share via replaceTrack - don't add/remove tracks
export async function replaceVideoTrack(pc, newTrack) {
  const sender = pc.getSenders().find(s => s.track?.kind === "video")
  if (sender) {
    await sender.replaceTrack(newTrack)
  }
}

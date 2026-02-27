export function getMediaConstraints(participantCount, video = true) {
  if (!video) {
    return {
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      },
      video: false
    }
  }

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
    const servers = metaTag ? JSON.parse(metaTag.content) : [{ urls: "stun:stun.l.google.com:19302" }]
    console.log("[Kazhat] ICE servers:", JSON.stringify(servers))
    return servers
  } catch (e) {
    console.error("[Kazhat] Failed to parse TURN servers:", e)
    return [{ urls: "stun:stun.l.google.com:19302" }]
  }
}

export function createPeerConnection(localStream, callbacks = {}) {
  const config = {
    iceServers: getTurnServers()
  }

  const pc = new RTCPeerConnection(config)
  console.log("[Kazhat] Created RTCPeerConnection")

  if (localStream) {
    const tracks = localStream.getTracks()
    console.log("[Kazhat] Adding", tracks.length, "local tracks to PC:", tracks.map(t => `${t.kind}:${t.enabled}:${t.readyState}`))
    tracks.forEach(track => {
      pc.addTrack(track, localStream)
    })
  } else {
    console.warn("[Kazhat] No local stream to add to PC!")
  }

  pc.ontrack = (event) => {
    console.log("[Kazhat] ontrack fired, track:", event.track.kind, "streams:", event.streams.length)
    if (callbacks.onTrack) {
      const stream = event.streams[0] || syncRemoteStream(pc)
      console.log("[Kazhat] Remote stream tracks:", stream.getTracks().map(t => `${t.kind}:${t.readyState}`))
      callbacks.onTrack(stream)
    }
  }

  pc.onicecandidate = (event) => {
    if (event.candidate && callbacks.onIceCandidate) {
      callbacks.onIceCandidate(event.candidate)
    }
    if (!event.candidate) {
      console.log("[Kazhat] ICE gathering complete")
    }
  }

  pc.oniceconnectionstatechange = () => {
    console.log("[Kazhat] ICE connection state:", pc.iceConnectionState)
    if (callbacks.onIceConnectionStateChange) {
      callbacks.onIceConnectionStateChange(pc.iceConnectionState)
    }
  }

  pc.onconnectionstatechange = () => {
    console.log("[Kazhat] Connection state:", pc.connectionState)
    if (callbacks.onConnectionStateChange) {
      callbacks.onConnectionStateChange(pc.connectionState)
    }
  }

  pc.onsignalingstatechange = () => {
    console.log("[Kazhat] Signaling state:", pc.signalingState)
  }

  pc.onicegatheringstatechange = () => {
    console.log("[Kazhat] ICE gathering state:", pc.iceGatheringState)
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
  console.log("[Kazhat] syncRemoteStream built stream with", stream.getTracks().length, "tracks")
  return stream
}

export async function createOffer(pc) {
  console.log("[Kazhat] Creating offer, signalingState:", pc.signalingState)
  const offer = await pc.createOffer()
  await pc.setLocalDescription(offer)
  console.log("[Kazhat] Offer created, SDP length:", offer.sdp?.length)
  return pc.localDescription
}

export async function createAnswer(pc) {
  console.log("[Kazhat] Creating answer, signalingState:", pc.signalingState)
  const answer = await pc.createAnswer()
  await pc.setLocalDescription(answer)
  console.log("[Kazhat] Answer created, SDP length:", answer.sdp?.length)
  return pc.localDescription
}

export async function handleOffer(pc, offer) {
  console.log("[Kazhat] handleOffer, signalingState:", pc.signalingState, "offer SDP length:", offer?.sdp?.length)
  if (pc.signalingState !== "stable") {
    console.warn("[Kazhat] Skipping offer: signalingState is", pc.signalingState)
    return null
  }
  await pc.setRemoteDescription(new RTCSessionDescription(offer))
  console.log("[Kazhat] Remote description set, creating answer")
  return await createAnswer(pc)
}

export async function handleAnswer(pc, answer) {
  console.log("[Kazhat] handleAnswer, signalingState:", pc.signalingState, "answer SDP length:", answer?.sdp?.length)
  if (pc.signalingState !== "have-local-offer") {
    console.warn("[Kazhat] Skipping answer: signalingState is", pc.signalingState)
    return
  }
  await pc.setRemoteDescription(new RTCSessionDescription(answer))
  console.log("[Kazhat] Remote description set successfully")
}

export async function handleIceCandidate(pc, candidate) {
  if (candidate) {
    try {
      await pc.addIceCandidate(new RTCIceCandidate(candidate))
    } catch (e) {
      console.warn("[Kazhat] Failed to add ICE candidate:", e.message)
    }
  }
}

// Screen share via replaceTrack - don't add/remove tracks
export async function replaceVideoTrack(pc, newTrack) {
  const sender = pc.getSenders().find(s => s.track?.kind === "video")
  if (sender) {
    await sender.replaceTrack(newTrack)
  }
}

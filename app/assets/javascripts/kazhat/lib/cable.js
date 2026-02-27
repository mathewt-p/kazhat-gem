import { createConsumer } from "@rails/actioncable"

let consumer = null

export function getConsumer() {
  if (!consumer) {
    const wsUrl = document.querySelector('meta[name="action-cable-url"]')?.content
    console.log("[Kazhat] Creating ActionCable consumer, wsUrl:", wsUrl || "(default /cable)")
    consumer = createConsumer(wsUrl)
  }
  return consumer
}

export function createSubscription(channel, params, callbacks) {
  const fullChannel = `Kazhat::${channel}`
  console.log("[Kazhat] Subscribing to:", fullChannel, "params:", params)
  return getConsumer().subscriptions.create(
    { channel: fullChannel, ...params },
    callbacks
  )
}

export function disconnectConsumer() {
  if (consumer) {
    consumer.disconnect()
    consumer = null
  }
}

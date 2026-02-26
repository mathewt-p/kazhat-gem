import { createConsumer } from "@rails/actioncable"

let consumer = null

export function getConsumer() {
  if (!consumer) {
    const wsUrl = document.querySelector('meta[name="action-cable-url"]')?.content
    consumer = createConsumer(wsUrl)
  }
  return consumer
}

export function createSubscription(channel, params, callbacks) {
  return getConsumer().subscriptions.create(
    { channel: `Kazhat::${channel}`, ...params },
    callbacks
  )
}

export function disconnectConsumer() {
  if (consumer) {
    consumer.disconnect()
    consumer = null
  }
}

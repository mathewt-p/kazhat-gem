module Kazhat
  class NotificationChannel < ApplicationCable::Channel
    def subscribed
      stream_for current_user
    end

    def self.notify_incoming_call(user, call)
      broadcast_to(user, {
        type: "incoming_call",
        call: {
          id: call.id,
          conversation_id: call.conversation_id,
          initiator: {
            id: call.initiator.id,
            name: call.initiator.kazhat_display_name
          },
          call_type: call.call_type,
          created_at: call.created_at.iso8601
        }
      })
    end

    def self.notify_new_message(user, message)
      broadcast_to(user, {
        type: "new_message",
        message: {
          id: message.id,
          conversation_id: message.conversation_id,
          sender: {
            id: message.sender_id,
            name: message.sender.kazhat_display_name
          },
          body: message.body,
          created_at: message.created_at.iso8601
        }
      })
    end
  end
end

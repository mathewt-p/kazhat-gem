module Kazhat
  class MessageChannel < ApplicationCable::Channel
    def subscribed
      @conversation = Kazhat::Conversation.find(params[:conversation_id])

      @participant = @conversation.participants.find_by(user_id: current_user.id)
      reject unless @participant

      stream_for @conversation
    end

    def typing(data)
      Kazhat::MessageChannel.broadcast_to(@conversation, {
        type: "typing",
        user_id: current_user.id,
        user_name: current_user.kazhat_display_name,
        is_typing: data["is_typing"]
      })
    end

    def unsubscribed
      return unless @conversation

      Kazhat::MessageChannel.broadcast_to(@conversation, {
        type: "typing",
        user_id: current_user.id,
        is_typing: false
      })
    end
  end
end

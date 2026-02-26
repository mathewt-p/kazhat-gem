module Kazhat
  class Message < ApplicationRecord
    self.table_name = "kazhat_messages"

    belongs_to :conversation, class_name: "Kazhat::Conversation"

    validates :body, presence: true

    scope :recent, -> { order(created_at: :desc) }
    scope :for_user, ->(user_id) {
      joins(conversation: :participants)
        .where(kazhat_conversation_participants: { user_id: user_id })
        .distinct
    }

    after_create_commit :broadcast_to_conversation

    def sender
      Kazhat.configuration.user_class_constant.find(sender_id)
    end

    private

    def broadcast_to_conversation
      Kazhat::MessageChannel.broadcast_to(
        conversation,
        {
          type: "new_message",
          message: {
            id: id,
            body: body,
            sender_id: sender_id,
            sender_name: sender.kazhat_display_name,
            created_at: created_at.iso8601
          }
        }
      )
    end
  end
end

module Kazhat
  class ConversationParticipant < ApplicationRecord
    self.table_name = "kazhat_conversation_participants"

    belongs_to :conversation, class_name: "Kazhat::Conversation"

    validates :user_id, uniqueness: { scope: :conversation_id }

    def user
      Kazhat.configuration.user_class_constant.find(user_id)
    end

    def mark_as_read!
      update!(last_read_at: Time.current)
    end
  end
end

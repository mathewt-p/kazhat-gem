module Kazhat
  module Chatable
    extend ActiveSupport::Concern

    included do
      has_many :kazhat_conversation_participants,
               class_name: "Kazhat::ConversationParticipant",
               foreign_key: :user_id,
               dependent: :destroy

      has_many :kazhat_conversations,
               through: :kazhat_conversation_participants,
               source: :conversation

      has_many :kazhat_sent_messages,
               class_name: "Kazhat::Message",
               foreign_key: :sender_id,
               dependent: :destroy

      has_many :kazhat_initiated_calls,
               class_name: "Kazhat::Call",
               foreign_key: :initiator_id,
               dependent: :destroy

      has_many :kazhat_call_participations,
               class_name: "Kazhat::CallParticipant",
               foreign_key: :user_id,
               dependent: :destroy
    end

    def kazhat_display_name
      if respond_to?(:display_name)
        display_name
      elsif respond_to?(:name)
        name
      else
        email
      end
    end
  end
end

module Kazhat
  class Conversation < ApplicationRecord
    self.table_name = "kazhat_conversations"

    has_many :participants,
             class_name: "Kazhat::ConversationParticipant",
             dependent: :destroy
    has_many :messages,
             class_name: "Kazhat::Message",
             dependent: :destroy
    has_many :calls,
             class_name: "Kazhat::Call",
             dependent: :destroy

    scope :for_user, ->(user_id) {
      joins(:participants)
        .where(kazhat_conversation_participants: { user_id: user_id })
        .distinct
    }

    def self.between_users(user1_id, user2_id)
      ids = [user1_id.to_i, user2_id.to_i].sort

      conversation = joins(:participants)
        .where(is_group: false)
        .where(kazhat_conversation_participants: { user_id: ids })
        .group("kazhat_conversations.id")
        .having("COUNT(kazhat_conversation_participants.id) = 2")
        .first

      return conversation if conversation

      transaction do
        conversation = create!(is_group: false)
        ids.each { |user_id| conversation.participants.create!(user_id: user_id) }
        conversation
      end
    end

    def other_participants(user_id)
      participants.where.not(user_id: user_id)
    end

    def unread_count_for(user_id)
      participant = participants.find_by(user_id: user_id)
      return 0 unless participant

      messages.where("created_at > ?", participant.last_read_at || Time.at(0)).count
    end

    def display_name_for(user_id)
      return name if is_group?

      other = other_participants(user_id).first
      other&.user&.kazhat_display_name || "Unknown"
    end
  end
end

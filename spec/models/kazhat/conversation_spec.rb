require "rails_helper"

RSpec.describe Kazhat::Conversation, type: :model do
  describe "associations" do
    it "has many participants" do
      assoc = described_class.reflect_on_association(:participants)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many messages" do
      assoc = described_class.reflect_on_association(:messages)
      expect(assoc.macro).to eq(:has_many)
    end

    it "has many calls" do
      assoc = described_class.reflect_on_association(:calls)
      expect(assoc.macro).to eq(:has_many)
    end
  end

  describe ".between_users" do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    it "creates a new conversation between two users" do
      conversation = described_class.between_users(user1.id, user2.id)
      expect(conversation).to be_persisted
      expect(conversation.is_group).to be false
      expect(conversation.participants.count).to eq(2)
    end

    it "returns existing conversation if one exists" do
      conv1 = described_class.between_users(user1.id, user2.id)
      conv2 = described_class.between_users(user1.id, user2.id)
      expect(conv1.id).to eq(conv2.id)
    end

    it "returns same conversation regardless of argument order" do
      conv1 = described_class.between_users(user1.id, user2.id)
      conv2 = described_class.between_users(user2.id, user1.id)
      expect(conv1.id).to eq(conv2.id)
    end
  end

  describe ".for_user" do
    it "returns conversations where user is a participant" do
      user = create(:user)
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)

      other_conversation = create(:kazhat_conversation)

      expect(described_class.for_user(user.id)).to include(conversation)
      expect(described_class.for_user(user.id)).not_to include(other_conversation)
    end
  end

  describe "#other_participants" do
    it "returns participants excluding the given user" do
      user1 = create(:user)
      user2 = create(:user)
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user1.id)
      p2 = create(:kazhat_conversation_participant, conversation: conversation, user_id: user2.id)

      others = conversation.other_participants(user1.id)
      expect(others).to include(p2)
      expect(others.count).to eq(1)
    end
  end

  describe "#unread_count_for" do
    it "returns count of messages after last_read_at" do
      user = create(:user)
      sender = create(:user)
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id, last_read_at: 1.hour.ago)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: sender.id)

      create(:kazhat_message, conversation: conversation, sender_id: sender.id, created_at: 30.minutes.ago)
      create(:kazhat_message, conversation: conversation, sender_id: sender.id, created_at: 2.hours.ago)

      expect(conversation.unread_count_for(user.id)).to eq(1)
    end

    it "returns 0 when user is not a participant" do
      user = create(:user)
      conversation = create(:kazhat_conversation)
      expect(conversation.unread_count_for(user.id)).to eq(0)
    end
  end

  describe "#display_name_for" do
    it "returns group name for group conversations" do
      conversation = create(:kazhat_conversation, :group, name: "Team Chat")
      expect(conversation.display_name_for(1)).to eq("Team Chat")
    end

    it "returns other participant name for 1:1 conversations" do
      user1 = create(:user, name: "Alice")
      user2 = create(:user, name: "Bob")
      conversation = described_class.between_users(user1.id, user2.id)

      expect(conversation.display_name_for(user1.id)).to eq("Bob")
      expect(conversation.display_name_for(user2.id)).to eq("Alice")
    end
  end
end

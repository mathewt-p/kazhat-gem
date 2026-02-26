require "rails_helper"

RSpec.describe Kazhat::Message, type: :model do
  describe "associations" do
    it "belongs to conversation" do
      assoc = described_class.reflect_on_association(:conversation)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has a sender method" do
      message = create(:kazhat_message)
      expect(message.sender).to be_a(User)
    end
  end

  describe "validations" do
    it "requires body" do
      message = build(:kazhat_message, body: nil)
      expect(message).not_to be_valid
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        conversation = create(:kazhat_conversation)
        sender = create(:user)
        old_msg = create(:kazhat_message, conversation: conversation, sender_id: sender.id, created_at: 1.hour.ago)
        new_msg = create(:kazhat_message, conversation: conversation, sender_id: sender.id, created_at: 1.minute.ago)

        expect(described_class.recent.first).to eq(new_msg)
      end
    end

    describe ".for_user" do
      it "returns messages in conversations where user participates" do
        user = create(:user)
        conversation = create(:kazhat_conversation)
        create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)
        message = create(:kazhat_message, conversation: conversation, sender_id: user.id)

        other_conversation = create(:kazhat_conversation)
        other_message = create(:kazhat_message, conversation: other_conversation, sender_id: create(:user).id)

        expect(described_class.for_user(user.id)).to include(message)
        expect(described_class.for_user(user.id)).not_to include(other_message)
      end
    end
  end
end

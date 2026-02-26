require "rails_helper"

RSpec.describe Kazhat::MessageChannel, type: :channel do
  let(:user) { create(:user) }
  let(:conversation) { create(:kazhat_conversation) }

  before do
    create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)
    stub_connection current_user: user
  end

  describe "#subscribed" do
    it "streams from the conversation" do
      subscribe conversation_id: conversation.id
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(conversation)
    end

    it "rejects non-participants" do
      other_conversation = create(:kazhat_conversation)
      subscribe conversation_id: other_conversation.id
      expect(subscription).to be_rejected
    end
  end

  describe "#typing" do
    it "broadcasts typing indicator" do
      subscribe conversation_id: conversation.id

      expect {
        perform :typing, is_typing: true
      }.to have_broadcasted_to(conversation)
    end
  end
end

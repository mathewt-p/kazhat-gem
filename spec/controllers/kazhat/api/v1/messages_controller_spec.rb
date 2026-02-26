require "rails_helper"

RSpec.describe Kazhat::Api::V1::MessagesController, type: :controller do
  routes { Kazhat::Engine.routes }

  let(:user) { create(:user) }
  let(:conversation) { create(:kazhat_conversation) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)
  end

  describe "GET #index" do
    it "returns messages for the conversation" do
      create(:kazhat_message, conversation: conversation, sender_id: user.id)

      get :index, params: { conversation_id: conversation.id }, format: :json
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["messages"].length).to eq(1)
    end

    it "returns forbidden for non-participant" do
      other_conversation = create(:kazhat_conversation)

      get :index, params: { conversation_id: other_conversation.id }, format: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST #create" do
    it "creates a message" do
      other_user = create(:user)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: other_user.id)

      expect {
        post :create, params: { conversation_id: conversation.id, body: "Hello!" }, format: :json
      }.to change(Kazhat::Message, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe "POST #mark_as_read" do
    it "marks messages as read" do
      post :mark_as_read, params: { conversation_id: conversation.id }, format: :json
      expect(response).to have_http_status(:ok)

      participant = conversation.participants.find_by(user_id: user.id)
      expect(participant.last_read_at).not_to be_nil
    end
  end
end

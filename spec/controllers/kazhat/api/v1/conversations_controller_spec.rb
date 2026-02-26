require "rails_helper"

RSpec.describe Kazhat::Api::V1::ConversationsController, type: :controller do
  routes { Kazhat::Engine.routes }

  let(:user) { create(:user) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "GET #index" do
    it "returns conversations for the current user" do
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)

      get :index, format: :json
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["conversations"].length).to eq(1)
    end

    it "does not return conversations user is not part of" do
      create(:kazhat_conversation)

      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json["conversations"].length).to eq(0)
    end
  end

  describe "POST #create" do
    it "creates a 1:1 conversation" do
      other_user = create(:user)

      post :create, params: { participant_ids: [other_user.id] }, format: :json
      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["conversation"]["is_group"]).to be false
    end

    it "creates a group conversation" do
      user2 = create(:user)
      user3 = create(:user)

      post :create, params: { participant_ids: [user2.id, user3.id], name: "Team" }, format: :json
      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["conversation"]["is_group"]).to be true
    end

    it "reuses existing 1:1 conversation" do
      other_user = create(:user)

      post :create, params: { participant_ids: [other_user.id] }, format: :json
      first_id = JSON.parse(response.body)["conversation"]["id"]

      post :create, params: { participant_ids: [other_user.id] }, format: :json
      second_id = JSON.parse(response.body)["conversation"]["id"]

      expect(first_id).to eq(second_id)
    end
  end

  describe "GET #show" do
    it "returns the conversation" do
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)

      get :show, params: { id: conversation.id }, format: :json
      expect(response).to have_http_status(:ok)
    end

    it "returns forbidden if user is not a participant" do
      conversation = create(:kazhat_conversation)

      get :show, params: { id: conversation.id }, format: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "authentication" do
    it "returns unauthorized when no current user" do
      allow(controller).to receive(:current_user).and_return(nil)

      get :index, format: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

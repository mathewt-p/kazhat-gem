require "rails_helper"

RSpec.describe Kazhat::Api::V1::CallsController, type: :controller do
  routes { Kazhat::Engine.routes }

  let(:user) { create(:user) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "GET #index" do
    it "returns calls for the current user" do
      call = create(:kazhat_call)
      create(:kazhat_call_participant, call: call, user_id: user.id)

      get :index, format: :json
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["calls"].length).to eq(1)
    end

    it "does not return calls user is not part of" do
      create(:kazhat_call)

      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json["calls"].length).to eq(0)
    end
  end

  describe "POST #create" do
    it "creates a call with another user" do
      other_user = create(:user)

      post :create, params: { user_id: other_user.id, call_type: "video" }, format: :json
      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["call"]["call_type"]).to eq("video")
      expect(json["call"]["status"]).to eq("ringing")
    end

    it "creates a call in an existing conversation" do
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)
      other_user = create(:user)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: other_user.id)

      post :create, params: { conversation_id: conversation.id }, format: :json
      expect(response).to have_http_status(:created)
    end

    it "creates participants for all conversation members" do
      other_user = create(:user)

      post :create, params: { user_id: other_user.id }, format: :json

      call = Kazhat::Call.last
      expect(call.call_participants.count).to eq(2)
      expect(call.call_participants.find_by(user_id: user.id).status).to eq("joined")
      expect(call.call_participants.find_by(user_id: other_user.id).status).to eq("ringing")
    end
  end

  describe "GET #show" do
    it "returns call details" do
      call = create(:kazhat_call)
      create(:kazhat_call_participant, call: call, user_id: user.id)

      get :show, params: { id: call.id }, format: :json
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["call"]["participants"]).to be_an(Array)
    end

    it "returns forbidden for non-participant" do
      call = create(:kazhat_call)

      get :show, params: { id: call.id }, format: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET #stats" do
    it "returns call statistics" do
      call = create(:kazhat_call, :ended)
      create(:kazhat_call_participant, :left, call: call, user_id: user.id)

      get :stats, format: :json
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["stats"]["total_calls"]).to eq(1)
    end
  end
end

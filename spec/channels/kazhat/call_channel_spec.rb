require "rails_helper"

RSpec.describe Kazhat::CallChannel, type: :channel do
  let(:user) { create(:user) }
  let(:call) { create(:kazhat_call) }

  before do
    stub_connection current_user: user
  end

  describe "#subscribed" do
    it "streams from the call" do
      subscribe call_id: call.id
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(call)
    end

    it "creates a call participant" do
      expect {
        subscribe call_id: call.id
      }.to change { call.call_participants.count }.by(1)
    end

    it "rejects when call is full" do
      5.times { create(:kazhat_call_participant, :joined, call: call) }

      subscribe call_id: call.id
      expect(subscription).to be_rejected
    end
  end

  describe "#answer" do
    before do
      subscribe call_id: call.id
    end

    it "joins the participant" do
      perform :answer
      participant = call.call_participants.find_by(user_id: user.id)
      expect(participant.status).to eq("joined")
    end
  end

  describe "#signal" do
    before do
      subscribe call_id: call.id
    end

    it "broadcasts signal to the call" do
      expect {
        perform :signal, signal: { type: "offer" }, target_peer_id: 123
      }.to have_broadcasted_to(call)
    end
  end

  describe "#unsubscribed" do
    it "marks ringing participant as missed" do
      subscribe call_id: call.id
      participant = call.call_participants.find_by(user_id: user.id)

      subscription.unsubscribe_from_channel
      expect(participant.reload.status).to eq("missed")
    end
  end
end

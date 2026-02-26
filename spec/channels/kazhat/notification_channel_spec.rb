require "rails_helper"

RSpec.describe Kazhat::NotificationChannel, type: :channel do
  let(:user) { create(:user) }

  before do
    stub_connection current_user: user
  end

  describe "#subscribed" do
    it "streams for the current user" do
      subscribe
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(user)
    end
  end

  describe ".notify_incoming_call" do
    it "broadcasts to the user" do
      call = create(:kazhat_call)

      expect {
        described_class.notify_incoming_call(user, call)
      }.to have_broadcasted_to(user).with(hash_including(type: "incoming_call"))
    end
  end

  describe ".notify_new_message" do
    it "broadcasts to the user" do
      message = create(:kazhat_message)

      expect {
        described_class.notify_new_message(user, message)
      }.to have_broadcasted_to(user).with(hash_including(type: "new_message"))
    end
  end
end

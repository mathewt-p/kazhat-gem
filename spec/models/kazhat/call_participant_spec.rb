require "rails_helper"

RSpec.describe Kazhat::CallParticipant, type: :model do
  describe "associations" do
    it "belongs to call" do
      assoc = described_class.reflect_on_association(:call)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has a user method" do
      participant = create(:kazhat_call_participant)
      expect(participant.user).to be_a(User)
    end
  end

  describe "validations" do
    it "validates status inclusion" do
      participant = build(:kazhat_call_participant, status: "invalid")
      expect(participant).not_to be_valid
    end

    it "validates user uniqueness per call" do
      user = create(:user)
      call = create(:kazhat_call)
      create(:kazhat_call_participant, call: call, user_id: user.id)

      duplicate = build(:kazhat_call_participant, call: call, user_id: user.id)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#join!" do
    it "sets status to joined" do
      participant = create(:kazhat_call_participant, status: "ringing")
      participant.join!
      expect(participant.reload.status).to eq("joined")
    end

    it "records joined_at" do
      participant = create(:kazhat_call_participant, status: "ringing")
      participant.join!
      expect(participant.joined_at).not_to be_nil
    end

    it "marks call as active when first participant joins" do
      call = create(:kazhat_call, status: "ringing")
      participant = create(:kazhat_call_participant, call: call, status: "ringing")
      participant.join!
      expect(call.reload.status).to eq("active")
    end
  end

  describe "#leave!" do
    it "sets status to left" do
      participant = create(:kazhat_call_participant, :joined)
      participant.leave!
      expect(participant.reload.status).to eq("left")
    end

    it "calculates duration" do
      participant = create(:kazhat_call_participant, status: "joined", joined_at: 5.minutes.ago)
      participant.leave!
      expect(participant.duration_seconds).to be_within(5).of(300)
    end

    it "does nothing if not joined" do
      participant = create(:kazhat_call_participant, status: "ringing")
      participant.leave!
      expect(participant.status).to eq("ringing")
    end

    it "ends call when last participant leaves" do
      call = create(:kazhat_call, :active)
      participant = create(:kazhat_call_participant, :joined, call: call)
      participant.leave!
      expect(call.reload.status).to eq("ended")
    end
  end

  describe "#reject!" do
    it "sets status to rejected" do
      participant = create(:kazhat_call_participant, status: "ringing")
      participant.reject!
      expect(participant.reload.status).to eq("rejected")
    end
  end

  describe "#formatted_duration" do
    it "returns em dash when no duration" do
      participant = build(:kazhat_call_participant, duration_seconds: nil)
      expect(participant.formatted_duration).to eq("\u2014")
    end

    it "formats correctly" do
      participant = build(:kazhat_call_participant, duration_seconds: 125)
      expect(participant.formatted_duration).to eq("2:05")
    end
  end
end

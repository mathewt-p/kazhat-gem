require "rails_helper"

RSpec.describe Kazhat::Call, type: :model do
  describe "associations" do
    it "belongs to conversation" do
      assoc = described_class.reflect_on_association(:conversation)
      expect(assoc.macro).to eq(:belongs_to)
    end

    it "has an initiator method" do
      call = create(:kazhat_call)
      expect(call.initiator).to be_a(User)
    end

    it "has many call_participants" do
      assoc = described_class.reflect_on_association(:call_participants)
      expect(assoc.macro).to eq(:has_many)
    end
  end

  describe "validations" do
    it "validates call_type inclusion" do
      call = build(:kazhat_call, call_type: "invalid")
      expect(call).not_to be_valid
    end

    it "validates status inclusion" do
      call = build(:kazhat_call, status: "invalid")
      expect(call).not_to be_valid
    end

    it "allows valid call_type" do
      %w[audio video].each do |type|
        call = build(:kazhat_call, call_type: type)
        expect(call).to be_valid
      end
    end
  end

  describe "#mark_as_active!" do
    it "transitions from ringing to active" do
      call = create(:kazhat_call, status: "ringing")
      call.mark_as_active!
      expect(call.reload.status).to eq("active")
    end

    it "records started_at timestamp" do
      call = create(:kazhat_call, status: "ringing")
      call.mark_as_active!
      expect(call.started_at).not_to be_nil
    end

    it "calculates ring_duration_seconds" do
      call = create(:kazhat_call, status: "ringing", created_at: 10.seconds.ago)
      call.mark_as_active!
      expect(call.ring_duration_seconds).to be_within(2).of(10)
    end

    it "does nothing if already active" do
      call = create(:kazhat_call, :active)
      original_started_at = call.started_at
      call.mark_as_active!
      expect(call.started_at).to eq(original_started_at)
    end
  end

  describe "#end_call!" do
    it "transitions to ended status" do
      call = create(:kazhat_call, :active)
      call.end_call!
      expect(call.reload.status).to eq("ended")
    end

    it "calculates total duration" do
      call = create(:kazhat_call, status: "active", started_at: 5.minutes.ago)
      call.end_call!
      expect(call.duration_seconds).to be_within(5).of(300)
    end

    it "does nothing if not active" do
      call = create(:kazhat_call, status: "ringing")
      call.end_call!
      expect(call.status).to eq("ringing")
    end

    it "marks remaining participants as left" do
      call = create(:kazhat_call, :active)
      participant = create(:kazhat_call_participant, :joined, call: call)
      call.end_call!
      expect(participant.reload.status).to eq("left")
    end
  end

  describe "#mark_as_missed!" do
    it "sets status to missed" do
      call = create(:kazhat_call, status: "ringing")
      create(:kazhat_call_participant, call: call, status: "ringing")
      call.mark_as_missed!
      expect(call.reload.status).to eq("missed")
    end

    it "marks ringing participants as missed" do
      call = create(:kazhat_call, status: "ringing")
      participant = create(:kazhat_call_participant, call: call, status: "ringing")
      call.mark_as_missed!
      expect(participant.reload.status).to eq("missed")
    end
  end

  describe "#can_add_participant?" do
    it "allows up to max participants" do
      call = create(:kazhat_call, :active)
      4.times { create(:kazhat_call_participant, :joined, call: call) }
      expect(call.can_add_participant?).to be true
    end

    it "blocks when at capacity" do
      call = create(:kazhat_call, :active)
      5.times { create(:kazhat_call_participant, :joined, call: call) }
      expect(call.can_add_participant?).to be false
    end
  end

  describe "#formatted_duration" do
    it "returns em dash when no duration" do
      call = build(:kazhat_call, duration_seconds: nil)
      expect(call.formatted_duration).to eq("\u2014")
    end

    it "formats minutes and seconds" do
      call = build(:kazhat_call, duration_seconds: 125)
      expect(call.formatted_duration).to eq("2:05")
    end

    it "formats hours when over 60 minutes" do
      call = build(:kazhat_call, duration_seconds: 3661)
      expect(call.formatted_duration).to eq("1:01:01")
    end
  end

  describe "scopes" do
    describe ".for_user" do
      it "returns calls where user is a participant" do
        user = create(:user)
        call = create(:kazhat_call)
        create(:kazhat_call_participant, call: call, user_id: user.id)

        other_call = create(:kazhat_call)

        expect(described_class.for_user(user.id)).to include(call)
        expect(described_class.for_user(user.id)).not_to include(other_call)
      end
    end

    describe ".completed" do
      it "returns only ended calls" do
        ended_call = create(:kazhat_call, :ended)
        active_call = create(:kazhat_call, :active)

        expect(described_class.completed).to include(ended_call)
        expect(described_class.completed).not_to include(active_call)
      end
    end
  end
end

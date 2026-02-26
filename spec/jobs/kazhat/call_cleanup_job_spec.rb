require "rails_helper"

RSpec.describe Kazhat::CallCleanupJob, type: :job do
  describe "#perform" do
    it "ends calls active for more than 8 hours" do
      stale_call = create(:kazhat_call, status: "active", started_at: 9.hours.ago)
      recent_call = create(:kazhat_call, status: "active", started_at: 1.hour.ago)

      described_class.perform_now

      expect(stale_call.reload.status).to eq("ended")
      expect(recent_call.reload.status).to eq("active")
    end

    it "marks ringing calls as missed after timeout" do
      old_ringing = create(:kazhat_call, status: "ringing", created_at: 5.minutes.ago)
      create(:kazhat_call_participant, call: old_ringing, status: "ringing")
      recent_ringing = create(:kazhat_call, status: "ringing", created_at: 10.seconds.ago)

      described_class.perform_now

      expect(old_ringing.reload.status).to eq("missed")
      expect(recent_ringing.reload.status).to eq("ringing")
    end
  end
end

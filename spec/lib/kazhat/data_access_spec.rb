require "rails_helper"

RSpec.describe Kazhat::DataAccess do
  let(:user) { create(:user) }

  describe ".calls_for_user" do
    it "returns calls for the user" do
      call = create(:kazhat_call, :ended)
      create(:kazhat_call_participant, :left, call: call, user_id: user.id)

      result = Kazhat.calls_for_user(user.id)
      expect(result).to include(call)
    end

    it "filters by date range" do
      old_call = create(:kazhat_call, :ended, started_at: 2.months.ago, ended_at: 2.months.ago)
      create(:kazhat_call_participant, :left, call: old_call, user_id: user.id)

      recent_call = create(:kazhat_call, :ended, started_at: 1.day.ago, ended_at: 1.day.ago)
      create(:kazhat_call_participant, :left, call: recent_call, user_id: user.id)

      result = Kazhat.calls_for_user(user.id, from: 1.week.ago)
      expect(result).to include(recent_call)
      expect(result).not_to include(old_call)
    end
  end

  describe ".messages_for_user" do
    it "returns messages for the user" do
      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)
      message = create(:kazhat_message, conversation: conversation, sender_id: user.id)

      result = Kazhat.messages_for_user(user.id)
      expect(result).to include(message)
    end
  end

  describe ".user_stats" do
    it "returns stats for the user" do
      call = create(:kazhat_call, :ended)
      create(:kazhat_call_participant, :left, call: call, user_id: user.id)

      conversation = create(:kazhat_conversation)
      create(:kazhat_conversation_participant, conversation: conversation, user_id: user.id)
      create(:kazhat_message, conversation: conversation, sender_id: user.id)

      stats = Kazhat.user_stats(user.id)

      expect(stats[:calls][:total]).to eq(1)
      expect(stats[:messages][:total_sent]).to eq(1)
    end

    it "respects period filter" do
      stats = Kazhat.user_stats(user.id, period: :week)
      expect(stats[:period]).to eq(:week)
    end
  end

  describe ".team_stats" do
    it "returns team-wide stats" do
      call = create(:kazhat_call, :ended)

      stats = Kazhat.team_stats
      expect(stats[:calls][:total]).to eq(1)
    end
  end

  describe ".call_history_for_export" do
    it "returns exportable call data" do
      call = create(:kazhat_call, :ended)
      create(:kazhat_call_participant, :left, call: call, user_id: user.id)

      result = Kazhat.call_history_for_export
      expect(result.length).to eq(1)
      expect(result.first[:call_id]).to eq(call.id)
      expect(result.first[:participants]).to be_an(Array)
    end
  end
end

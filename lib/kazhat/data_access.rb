module Kazhat
  module DataAccess
    def calls_for_user(user_id, from: nil, to: nil)
      calls = Kazhat::Call.for_user(user_id)
                          .includes(:call_participants)
      calls = calls.where("started_at >= ?", from) if from
      calls = calls.where("started_at <= ?", to) if to
      calls
    end

    def messages_for_user(user_id, from: nil, to: nil)
      messages = Kazhat::Message.for_user(user_id)
                                .includes(:conversation)
      messages = messages.where("kazhat_messages.created_at >= ?", from) if from
      messages = messages.where("kazhat_messages.created_at <= ?", to) if to
      messages
    end

    def user_stats(user_id, period: :all_time)
      from_date = case period
        when :week then 1.week.ago
        when :month then 1.month.ago
        when :year then 1.year.ago
        else nil
      end

      calls = calls_for_user(user_id, from: from_date).completed
      messages = messages_for_user(user_id, from: from_date)

      {
        period: period,
        calls: {
          total: calls.count,
          total_duration_seconds: calls.sum(:duration_seconds),
          average_duration_seconds: calls.average(:duration_seconds)&.to_i || 0,
          video_calls: calls.where(call_type: "video").count,
          audio_calls: calls.where(call_type: "audio").count
        },
        messages: {
          total_sent: messages.where(sender_id: user_id).count,
          total_received: messages.where.not(sender_id: user_id).count,
          conversations: Kazhat::Conversation.for_user(user_id).count
        }
      }
    end

    def team_stats(from: nil, to: nil)
      calls = Kazhat::Call.completed
      calls = calls.where("started_at >= ?", from) if from
      calls = calls.where("started_at <= ?", to) if to

      messages = Kazhat::Message.all
      messages = messages.where("created_at >= ?", from) if from
      messages = messages.where("created_at <= ?", to) if to

      {
        calls: {
          total: calls.count,
          total_duration_seconds: calls.sum(:duration_seconds),
          average_duration_seconds: calls.average(:duration_seconds)&.to_i || 0,
          unique_users: Kazhat::CallParticipant.joins(:call)
                          .merge(calls)
                          .distinct
                          .count(:user_id)
        },
        messages: {
          total: messages.count,
          unique_senders: messages.distinct.count(:sender_id),
          active_conversations: Kazhat::Conversation
                                  .joins(:messages)
                                  .merge(messages)
                                  .distinct
                                  .count
        }
      }
    end

    def call_history_for_export(from: nil, to: nil)
      calls = Kazhat::Call.completed
                          .includes(:call_participants)
      calls = calls.where("started_at >= ?", from) if from
      calls = calls.where("started_at <= ?", to) if to

      calls.map do |call|
        {
          call_id: call.id,
          initiator_id: call.initiator_id,
          initiator_name: call.initiator.kazhat_display_name,
          call_type: call.call_type,
          started_at: call.started_at,
          ended_at: call.ended_at,
          duration_seconds: call.duration_seconds,
          participants: call.call_participants.map do |p|
            {
              user_id: p.user_id,
              user_name: p.user.kazhat_display_name,
              joined_at: p.joined_at,
              left_at: p.left_at,
              duration_seconds: p.duration_seconds
            }
          end
        }
      end
    end
  end
end

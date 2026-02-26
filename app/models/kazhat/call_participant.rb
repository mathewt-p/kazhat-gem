module Kazhat
  class CallParticipant < ApplicationRecord
    self.table_name = "kazhat_call_participants"

    belongs_to :call, class_name: "Kazhat::Call"

    validates :user_id, uniqueness: { scope: :call_id }
    validates :status, inclusion: { in: %w[ringing joined left rejected missed busy] }

    def user
      Kazhat.configuration.user_class_constant.find(user_id)
    end

    def join!
      update!(
        status: "joined",
        joined_at: Time.current
      )

      if call.call_participants.where(status: "joined").count == 1
        call.mark_as_active!
      end
    end

    def leave!(time = Time.current)
      return unless status == "joined"

      duration = (time - joined_at).to_i
      update!(
        status: "left",
        left_at: time,
        duration_seconds: duration
      )

      if call.active_participants.none?
        call.end_call!
      end
    end

    def reject!
      update!(status: "rejected")
    end

    def formatted_duration
      return "\u2014" unless duration_seconds

      minutes = duration_seconds / 60
      seconds = duration_seconds % 60
      "%d:%02d" % [minutes, seconds]
    end
  end
end

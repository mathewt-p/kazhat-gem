module Kazhat
  class Call < ApplicationRecord
    self.table_name = "kazhat_calls"

    belongs_to :conversation, class_name: "Kazhat::Conversation"
    has_many :call_participants, class_name: "Kazhat::CallParticipant", dependent: :destroy

    validates :call_type, inclusion: { in: %w[audio video] }
    validates :status, inclusion: { in: %w[ringing active ended missed cancelled] }

    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: "ended") }
    scope :for_user, ->(user_id) {
      joins(:call_participants)
        .where(kazhat_call_participants: { user_id: user_id })
        .distinct
    }

    def initiator
      Kazhat.configuration.user_class_constant.find(initiator_id)
    end

    def mark_as_active!
      return if status == "active"

      update!(
        status: "active",
        started_at: Time.current,
        ring_duration_seconds: (Time.current - created_at).to_i
      )
    end

    def end_call!
      return unless status == "active"

      now = Time.current
      update!(
        status: "ended",
        ended_at: now,
        duration_seconds: (now - started_at).to_i,
        total_participant_seconds: call_participants.sum(:duration_seconds),
        max_participants_reached: [max_participants_reached, call_participants.where(status: "joined").count].max
      )

      call_participants.where(left_at: nil).each { |p| p.leave!(now) }
    end

    def mark_as_missed!
      update!(status: "missed", ended_at: Time.current)
      call_participants.where(status: "ringing").update_all(status: "missed")
    end

    def active_participants
      call_participants.where(status: "joined")
    end

    def can_add_participant?
      active_participants.count < Kazhat.configuration.max_call_participants
    end

    def formatted_duration
      return "\u2014" unless duration_seconds

      hours = duration_seconds / 3600
      minutes = (duration_seconds % 3600) / 60
      seconds = duration_seconds % 60

      if hours > 0
        "%d:%02d:%02d" % [hours, minutes, seconds]
      else
        "%d:%02d" % [minutes, seconds]
      end
    end

    def average_participant_duration
      return 0 if call_participants.empty?
      total_participant_seconds / call_participants.count
    end
  end
end

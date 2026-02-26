module Kazhat
  class CallChannel < ApplicationCable::Channel
    def subscribed
      @call = Kazhat::Call.find(params[:call_id])
      @participant = @call.call_participants.find_or_create_by!(user_id: current_user.id) do |p|
        p.rang_at = Time.current
        p.status = "ringing"
      end

      unless @call.can_add_participant?
        transmit({ type: "error", message: "Call is full" })
        reject
        return
      end

      stream_for @call
    end

    def answer(_data)
      @participant.join!

      broadcast_to_others({
        type: "participant_joined",
        participant: serialize_participant(@participant),
        participants: all_participants
      })

      transmit({
        type: "existing_participants",
        participants: other_participants
      })
    end

    def signal(data)
      Kazhat::CallChannel.broadcast_to(@call, {
        type: "signal",
        from_peer_id: @participant.id,
        signal: data["signal"],
        target_peer_id: data["target_peer_id"]
      })
    end

    def reject_call(_data)
      @participant.reject!

      broadcast_to_others({
        type: "participant_rejected",
        participant_id: @participant.user_id
      })
    end

    def unsubscribed
      return unless @participant

      case @participant.status
      when "ringing"
        @participant.update!(status: "missed")
      when "joined"
        @participant.leave!
      end

      broadcast_to_others({
        type: "participant_left",
        participant_id: @participant.user_id,
        participants: all_participants
      })
    end

    private

    def serialize_participant(p)
      {
        id: p.user_id,
        peer_id: p.id,
        name: p.user.kazhat_display_name,
        status: p.status,
        joined_at: p.joined_at&.iso8601
      }
    end

    def all_participants
      @call.call_participants.map { |p| serialize_participant(p) }
    end

    def other_participants
      @call.call_participants.where.not(id: @participant.id).map { |p| serialize_participant(p) }
    end

    def broadcast_to_others(data)
      Kazhat::CallChannel.broadcast_to(@call, data)
    end
  end
end

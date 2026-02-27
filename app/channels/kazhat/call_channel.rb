module Kazhat
  class CallChannel < ApplicationCable::Channel
    def subscribed
      @call = Kazhat::Call.find(params[:call_id])
      @participant = @call.call_participants.find_or_create_by!(user_id: current_user.id) do |p|
        p.rang_at = Time.current
        p.status = "ringing"
      end

      unless @call.can_add_participant?
        Rails.logger.info "[Kazhat] Call #{@call.id} is full, rejecting user #{current_user.id}"
        transmit({ type: "error", message: "Call is full" })
        reject
        return
      end

      Rails.logger.info "[Kazhat] User #{current_user.id} subscribed to call #{@call.id}, participant #{@participant.id}"
      stream_for @call
    end

    def answer(_data)
      @participant.join!
      Rails.logger.info "[Kazhat] User #{current_user.id} answered call #{@call.id}"

      other = other_participants
      Rails.logger.info "[Kazhat] Broadcasting participant_joined, existing participants: #{other.map { |p| p[:id] }}"

      broadcast_to_others({
        type: "participant_joined",
        participant: serialize_participant(@participant),
        participants: all_participants
      })

      Rails.logger.info "[Kazhat] Transmitting existing_participants to user #{current_user.id}: #{other.map { |p| p[:id] }}"
      transmit({
        type: "existing_participants",
        participants: other
      })
    end

    def signal(data)
      Rails.logger.info "[Kazhat] Signal from user #{current_user.id}: type=#{data['signal']&.dig('type')} target=#{data['target_user_id']}"
      Kazhat::CallChannel.broadcast_to(@call, {
        type: "signal",
        from_user_id: current_user.id,
        signal: data["signal"],
        target_user_id: data["target_user_id"]
      })
    end

    def reject_call(_data)
      @participant.reject!
      Rails.logger.info "[Kazhat] User #{current_user.id} rejected call #{@call.id}"

      broadcast_to_others({
        type: "participant_rejected",
        participant_id: @participant.user_id
      })
    end

    def unsubscribed
      return unless @participant

      Rails.logger.info "[Kazhat] User #{current_user.id} unsubscribed from call #{@call.id}, status was: #{@participant.status}"

      case @participant.status
      when "ringing"
        @participant.update!(status: "missed")
      when "joined"
        @participant.leave!
      end

      broadcast_to_others({
        type: "participant_left",
        participant_id: @participant.user_id,
        peer_id: @participant.id,
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
      @call.call_participants.where.not(id: @participant.id).where(status: "joined").map { |p| serialize_participant(p) }
    end

    def broadcast_to_others(data)
      Kazhat::CallChannel.broadcast_to(@call, data)
    end
  end
end

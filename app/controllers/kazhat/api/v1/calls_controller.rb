module Kazhat
  module Api
    module V1
      class CallsController < BaseController
        def index
          calls = Kazhat::Call.for_user(current_user.id)
                    .includes(:call_participants)
                    .recent

          calls = calls.where(call_type: params[:call_type]) if params[:call_type]
          calls = calls.where(status: params[:status]) if params[:status]
          calls = calls.where("started_at >= ?", params[:from_date]) if params[:from_date]
          calls = calls.where("started_at <= ?", params[:to_date]) if params[:to_date]

          if calls.respond_to?(:page)
            calls = calls.page(params[:page]).per(params[:per_page] || 20)
          end

          render json: {
            calls: calls.map { |call| serialize_call(call) },
            meta: pagination_meta(calls)
          }
        end

        def show
          call = Kazhat::Call.find(params[:id])
          return unless authorize_call_access!(call)

          render json: {
            call: serialize_call_detailed(call)
          }
        end

        def create
          conversation = if params[:conversation_id]
            Kazhat::Conversation.find(params[:conversation_id])
          else
            Kazhat::Conversation.between_users(current_user.id, params[:user_id])
          end

          call = conversation.calls.create!(
            initiator_id: current_user.id,
            call_type: params[:call_type] || "video",
            status: "ringing"
          )

          call.call_participants.create!(
            user_id: current_user.id,
            status: "joined",
            rang_at: Time.current,
            joined_at: Time.current
          )

          conversation.other_participants(current_user.id).each do |participant|
            call.call_participants.create!(
              user_id: participant.user_id,
              status: "ringing",
              rang_at: Time.current
            )

            Kazhat::NotificationChannel.notify_incoming_call(participant.user, call)
          end

          render json: { call: serialize_call(call) }, status: :created
        end

        def stats
          user_calls = Kazhat::Call.for_user(current_user.id).completed

          render json: {
            stats: {
              total_calls: user_calls.count,
              total_duration: user_calls.sum(:duration_seconds),
              average_duration: user_calls.average(:duration_seconds)&.to_i || 0,
              total_video_calls: user_calls.where(call_type: "video").count,
              total_audio_calls: user_calls.where(call_type: "audio").count,

              this_week: {
                calls: user_calls.where("started_at >= ?", 1.week.ago).count,
                duration: user_calls.where("started_at >= ?", 1.week.ago).sum(:duration_seconds)
              },

              this_month: {
                calls: user_calls.where("started_at >= ?", 1.month.ago).count,
                duration: user_calls.where("started_at >= ?", 1.month.ago).sum(:duration_seconds)
              },

              frequent_partners: frequent_call_partners(current_user.id, limit: 5)
            }
          }
        end

        private

        def serialize_call(call)
          my_participation = call.call_participants.find_by(user_id: current_user.id)

          {
            id: call.id,
            call_type: call.call_type,
            status: call.status,
            initiator: {
              id: call.initiator.id,
              name: call.initiator.kazhat_display_name
            },
            started_at: call.started_at&.iso8601,
            ended_at: call.ended_at&.iso8601,
            duration: call.formatted_duration,
            duration_seconds: call.duration_seconds,
            participant_count: call.call_participants.count,
            my_duration: my_participation&.formatted_duration,
            my_duration_seconds: my_participation&.duration_seconds,
            created_at: call.created_at.iso8601
          }
        end

        def serialize_call_detailed(call)
          serialize_call(call).merge(
            participants: call.call_participants.map do |participant|
              {
                id: participant.user.id,
                name: participant.user.kazhat_display_name,
                status: participant.status,
                joined_at: participant.joined_at&.iso8601,
                left_at: participant.left_at&.iso8601,
                duration: participant.formatted_duration,
                duration_seconds: participant.duration_seconds
              }
            end,
            ring_duration_seconds: call.ring_duration_seconds,
            max_participants_reached: call.max_participants_reached,
            total_participant_seconds: call.total_participant_seconds
          )
        end

        def frequent_call_partners(user_id, limit: 5)
          Kazhat::Call.joins(:call_participants)
            .where(kazhat_call_participants: { user_id: user_id })
            .where.not(initiator_id: user_id)
            .group("kazhat_calls.initiator_id")
            .order(Arel.sql("COUNT(*) DESC"))
            .limit(limit)
            .count
            .map do |partner_id, count|
              partner = Kazhat.configuration.user_class_constant.find(partner_id)
              {
                id: partner.id,
                name: partner.kazhat_display_name,
                call_count: count
              }
            end
        end

        def authorize_call_access!(call)
          participant = call.call_participants.find_by(user_id: current_user.id)
          unless participant
            render json: { error: "Not authorized" }, status: :forbidden
            return false
          end
          true
        end
      end
    end
  end
end

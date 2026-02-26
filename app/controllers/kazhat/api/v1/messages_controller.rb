module Kazhat
  module Api
    module V1
      class MessagesController < BaseController
        before_action :set_conversation

        def index
          messages = @conversation.messages.order(created_at: :desc)

          if messages.respond_to?(:page)
            messages = messages.page(params[:page]).per(params[:per_page] || 50)
          end

          render json: {
            messages: messages.map { |m| serialize_message(m) },
            meta: pagination_meta(messages)
          }
        end

        def create
          message = @conversation.messages.create!(
            sender_id: current_user.id,
            body: params[:body]
          )

          # Notify other participants
          @conversation.other_participants(current_user.id).each do |participant|
            Kazhat::NotificationChannel.notify_new_message(participant.user, message)
          end

          render json: { message: serialize_message(message) }, status: :created
        end

        def mark_as_read
          participant = @conversation.participants.find_by!(user_id: current_user.id)
          participant.mark_as_read!

          head :ok
        end

        private

        def set_conversation
          @conversation = Kazhat::Conversation.find(params[:conversation_id])
          authorize_conversation!
        end

        def authorize_conversation!
          participant = @conversation.participants.find_by(user_id: current_user.id)
          render json: { error: "Not authorized" }, status: :forbidden unless participant
        end

        def serialize_message(message)
          {
            id: message.id,
            body: message.body,
            sender_id: message.sender_id,
            sender_name: message.sender.kazhat_display_name,
            created_at: message.created_at.iso8601,
            edited_at: message.edited_at&.iso8601
          }
        end
      end
    end
  end
end

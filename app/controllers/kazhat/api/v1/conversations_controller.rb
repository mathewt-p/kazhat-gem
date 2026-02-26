module Kazhat
  module Api
    module V1
      class ConversationsController < BaseController
        def index
          conversations = Kazhat::Conversation
            .for_user(current_user.id)
            .includes(:participants, :messages)

          render json: {
            conversations: conversations.map { |c| serialize_conversation(c) }
          }
        end

        def create
          if params[:participant_ids].length == 1
            other_user_id = params[:participant_ids].first
            conversation = Kazhat::Conversation.between_users(current_user.id, other_user_id)
          else
            conversation = Kazhat::Conversation.create!(
              is_group: true,
              name: params[:name]
            )

            ([current_user.id] + params[:participant_ids]).each do |user_id|
              conversation.participants.create!(user_id: user_id)
            end
          end

          render json: { conversation: serialize_conversation(conversation) }, status: :created
        end

        def show
          conversation = Kazhat::Conversation.find(params[:id])
          return unless authorize_conversation!(conversation)

          render json: { conversation: serialize_conversation(conversation) }
        end

        private

        def serialize_conversation(conversation)
          last_message = conversation.messages.order(created_at: :desc).first

          {
            id: conversation.id,
            is_group: conversation.is_group,
            name: conversation.display_name_for(current_user.id),
            participants: conversation.participants.map { |p|
              {
                id: p.user.id,
                name: p.user.kazhat_display_name
              }
            },
            last_message: last_message ? {
              body: last_message.body,
              sender_id: last_message.sender_id,
              sender_name: last_message.sender.kazhat_display_name,
              created_at: last_message.created_at.iso8601
            } : nil,
            unread_count: conversation.unread_count_for(current_user.id),
            created_at: conversation.created_at.iso8601
          }
        end

        def authorize_conversation!(conversation)
          participant = conversation.participants.find_by(user_id: current_user.id)
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

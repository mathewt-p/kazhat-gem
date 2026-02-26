module Kazhat
  class ConversationsController < ApplicationController
    def index
      @conversations = Kazhat::Conversation
        .for_user(current_user.id)
        .includes(:participants, :messages)
    end

    def show
      @conversation = Kazhat::Conversation.find(params[:id])
      @messages = @conversation.messages.order(created_at: :asc)
    end
  end
end

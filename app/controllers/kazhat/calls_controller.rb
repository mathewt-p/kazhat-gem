module Kazhat
  class CallsController < ApplicationController
    def index
      @calls = Kazhat::Call
        .for_user(current_user.id)
        .includes(:call_participants)
        .recent
    end

    def show
      @call = Kazhat::Call.find(params[:id])
    end
  end
end

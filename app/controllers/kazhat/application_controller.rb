module Kazhat
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    private

    def current_user
      @current_user ||= send(Kazhat.configuration.current_user_method)
    end
    helper_method :current_user
  end
end

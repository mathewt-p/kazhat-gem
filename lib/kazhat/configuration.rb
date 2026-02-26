module Kazhat
  class Configuration
    attr_accessor :user_class,
                  :current_user_method,
                  :max_call_participants,
                  :call_timeout,
                  :turn_servers,
                  :video_quality

    def initialize
      @user_class = "User"
      @current_user_method = :current_user
      @max_call_participants = 5
      @call_timeout = 30
      @turn_servers = [
        { urls: "stun:stun.l.google.com:19302" }
      ]
      @video_quality = {
        2 => { width: 1280, height: 720, fps: 30 },
        3 => { width: 960, height: 540, fps: 24 },
        4 => { width: 640, height: 480, fps: 20 },
        5 => { width: 640, height: 480, fps: 20 }
      }
    end

    def user_class_constant
      user_class.constantize
    end
  end
end

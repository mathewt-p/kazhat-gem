Kazhat.configure do |config|
  # Required: Your User model
  config.user_class = "User"

  # Required: Method to get current user in controllers/channels
  config.current_user_method = :current_user

  # Optional: Call settings
  config.max_call_participants = 5
  config.call_timeout = 30

  # Optional: TURN server (recommended for production)
  # Sign up at https://www.twilio.com/docs/stun-turn or https://xirsys.com
  config.turn_servers = [
    {
      urls: ENV.fetch("TURN_URL", "stun:stun.l.google.com:19302"),
      username: ENV["TURN_USERNAME"],
      credential: ENV["TURN_CREDENTIAL"]
    }
  ]

  # Optional: Video quality by participant count
  # Automatically degrades quality as more people join
  config.video_quality = {
    2 => { width: 1280, height: 720, fps: 30 },  # HD for 2 people
    3 => { width: 960, height: 540, fps: 24 },
    4 => { width: 640, height: 480, fps: 20 },    # SD for 4-5 people
    5 => { width: 640, height: 480, fps: 20 }
  }
end

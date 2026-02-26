# Kazhat

Real-time video calling and messaging for Rails applications. Kazhat is a mountable Rails engine that adds WebRTC-based video/audio calls and a messaging system to any Rails app.

## Requirements

- Ruby >= 3.0
- Rails >= 7.0
- Redis (required for ActionCable in production)
- A `User` model (or equivalent) in your host application

## Installation

Add to your Gemfile:

```ruby
gem "kazhat", git: "https://github.com/mathewt-p/kazhat-gem.git"
```

Run:

```bash
bundle install
```

Then run the install generator:

```bash
rails generate kazhat:install
```

The generator will:

1. Create `config/initializers/kazhat.rb` with default configuration
2. Copy database migrations
3. Mount the engine at `/kazhat` in your routes
4. Inject `Kazhat::CableAuth` into your ActionCable connection
5. Add `kazhat_meta_tags` and `kazhat_call_container` to your layout
6. Set up importmap pins (if using importmap)

Finally, run the migrations:

```bash
rails db:migrate
```

## Configuration

Edit `config/initializers/kazhat.rb`:

```ruby
Kazhat.configure do |config|
  # The user model class name in your app
  config.user_class = "User"

  # Controller method that returns the current authenticated user
  config.current_user_method = :current_user

  # Maximum participants per call (mesh topology, recommended max: 5)
  config.max_call_participants = 5

  # Seconds before a ringing call is marked as missed
  config.call_timeout = 30

  # TURN/STUN servers for WebRTC
  config.turn_servers = [
    {
      urls: ENV.fetch("TURN_URL", "stun:stun.l.google.com:19302"),
      username: ENV["TURN_USERNAME"],
      credential: ENV["TURN_CREDENTIAL"]
    }
  ]

  # Video quality profiles keyed by participant count
  config.video_quality = {
    2 => { width: 1280, height: 720, fps: 30 },
    3 => { width: 960, height: 540, fps: 24 },
    4 => { width: 640, height: 480, fps: 20 },
    5 => { width: 640, height: 480, fps: 20 }
  }
end
```

## User Model Setup

Kazhat automatically includes the `Kazhat::Chatable` concern into your User model. This adds:

**Associations:**
- `kazhat_conversations` - conversations the user participates in
- `kazhat_sent_messages` - messages sent by the user
- `kazhat_initiated_calls` - calls initiated by the user
- `kazhat_call_participations` - call participations

**Display name resolution** (`kazhat_display_name`):

Kazhat looks for a display name on your User model in this order:
1. `display_name` method
2. `name` method
3. `email` attribute

If none of these exist, implement `kazhat_display_name` on your User model:

```ruby
class User < ApplicationRecord
  def kazhat_display_name
    "#{first_name} #{last_name}"
  end
end
```

## ActionCable Setup

Kazhat requires ActionCable for real-time features. The install generator injects `Kazhat::CableAuth` into your `ApplicationCable::Connection`, which handles WebSocket authentication via:

1. Warden/Devise session (`env["warden"].user`)
2. Fallback to `session[:user_id]`

Make sure your `config/cable.yml` uses Redis in production:

```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/1") %>
```

## View Helpers

Kazhat provides three helpers for your layouts and views:

### `kazhat_meta_tags`

Outputs `<meta>` tags with Kazhat configuration (API URL, TURN servers, user ID, etc.). Added to `<head>` by the install generator.

### `kazhat_call_container`

Renders the main container div for the call UI with notification handling. Added before `</body>` by the install generator.

### `kazhat_quick_call_button(user, **options)`

Renders a button to initiate a call with another user:

```erb
<%= kazhat_quick_call_button(@user) %>
<%= kazhat_quick_call_button(@user, text: "Video Chat", call_type: "video", class: "btn btn-primary") %>
<%= kazhat_quick_call_button(@user, call_type: "audio", text: "Voice Call") %>
```

## API Endpoints

All API endpoints are under `/kazhat/api/v1/` and require authentication. Responses are JSON.

### Conversations

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/conversations` | List conversations for current user |
| `POST` | `/api/v1/conversations` | Create a conversation |
| `GET` | `/api/v1/conversations/:id` | Show a conversation |

**Create a 1:1 conversation:**

```bash
POST /kazhat/api/v1/conversations
Content-Type: application/json

{ "participant_ids": [42] }
```

1:1 conversations are automatically reused — calling this with the same user returns the existing conversation.

**Create a group conversation:**

```bash
POST /kazhat/api/v1/conversations
Content-Type: application/json

{ "participant_ids": [42, 43, 44], "name": "Project Team" }
```

### Messages

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/conversations/:conversation_id/messages` | List messages (paginated) |
| `POST` | `/api/v1/conversations/:conversation_id/messages` | Send a message |
| `POST` | `/api/v1/conversations/:conversation_id/messages/read` | Mark as read |

**Send a message:**

```bash
POST /kazhat/api/v1/conversations/1/messages
Content-Type: application/json

{ "body": "Hello!" }
```

**Pagination params:** `page`, `per_page` (default: 50)

### Calls

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/calls` | List calls for current user |
| `POST` | `/api/v1/calls` | Initiate a call |
| `GET` | `/api/v1/calls/:id` | Show call details with participants |
| `GET` | `/api/v1/calls/stats` | Get call statistics |

**Start a call with a user:**

```bash
POST /kazhat/api/v1/calls
Content-Type: application/json

{ "user_id": 42, "call_type": "video" }
```

**Start a call in an existing conversation:**

```bash
POST /kazhat/api/v1/calls
Content-Type: application/json

{ "conversation_id": 1, "call_type": "audio" }
```

**Filter calls:**

```
GET /kazhat/api/v1/calls?call_type=video&status=ended&from_date=2025-01-01&to_date=2025-12-31&page=1&per_page=20
```

## ActionCable Channels

### CallChannel

Subscribe with `{ channel: "Kazhat::CallChannel", call_id: 123 }`.

| Action | Description |
|--------|-------------|
| `answer` | Accept the call, join as participant |
| `signal` | Relay WebRTC signaling data (`{ signal: {...}, target_peer_id: 456 }`) |
| `reject_call` | Reject the incoming call |

**Broadcast events:**
- `participant_joined` — a participant answered the call
- `participant_left` — a participant left the call
- `participant_rejected` — a participant rejected the call
- `signal` — WebRTC signaling data (SDP offers/answers, ICE candidates)
- `existing_participants` — sent to the joining participant with current call state

### MessageChannel

Subscribe with `{ channel: "Kazhat::MessageChannel", conversation_id: 123 }`.

| Action | Description |
|--------|-------------|
| `typing` | Broadcast typing indicator (`{ is_typing: true }`) |

**Broadcast events:**
- `typing` — typing indicator with `user_id`, `user_name`, `is_typing`
- `new_message` — new message broadcast (triggered by message creation)

### NotificationChannel

Subscribe with `{ channel: "Kazhat::NotificationChannel" }`. Streams per-user notifications.

**Broadcast events:**
- `incoming_call` — incoming call notification with call details
- `new_message` — new message notification with message preview

## Data Access for Host Apps

Kazhat exposes data access methods directly on the `Kazhat` module for use in your application code:

```ruby
# Get calls for a user, optionally filtered by date range
calls = Kazhat.calls_for_user(user.id, from: 1.week.ago, to: Time.current)

# Get messages for a user
messages = Kazhat.messages_for_user(user.id, from: 1.month.ago)

# User statistics for a period (:week, :month, :year, :all_time)
stats = Kazhat.user_stats(user.id, period: :month)
# => {
#   period: :month,
#   calls: { total: 15, total_duration_seconds: 5400, average_duration_seconds: 360,
#            video_calls: 12, audio_calls: 3 },
#   messages: { total_sent: 120, total_received: 95, conversations: 8 }
# }

# Team-wide statistics
team = Kazhat.team_stats(from: 1.month.ago)
# => {
#   calls: { total: 200, total_duration_seconds: 72000, average_duration_seconds: 360,
#            unique_users: 25 },
#   messages: { total: 3500, unique_senders: 30, active_conversations: 45 }
# }

# Export call history
export = Kazhat.call_history_for_export(from: 1.month.ago)
# => [{ call_id: 1, initiator_id: 1, initiator_name: "John", call_type: "video",
#        started_at: ..., ended_at: ..., duration_seconds: 300,
#        participants: [{ user_id: 1, user_name: "John", joined_at: ..., left_at: ..., duration_seconds: 300 }] }]
```

## Background Jobs

### CallCleanupJob

Handles stale calls:

- **Ends active calls** that have been running for more than 8 hours (likely crashed/orphaned)
- **Marks ringing calls as missed** after the configured `call_timeout` (default: 30 seconds)

Schedule this job to run periodically (e.g., every minute) using your preferred scheduler:

```ruby
# Using Sidekiq-Cron
Sidekiq::Cron::Job.create(name: "kazhat_call_cleanup", cron: "* * * * *", class: "Kazhat::CallCleanupJob")

# Using Whenever
every 1.minute do
  runner "Kazhat::CallCleanupJob.perform_later"
end

# Using solid_queue recurring tasks (Rails 8+)
# config/recurring.yml
kazhat_cleanup:
  class: Kazhat::CallCleanupJob
  schedule: every minute
```

## Database Schema

Kazhat creates 5 tables:

| Table | Purpose |
|-------|---------|
| `kazhat_conversations` | Conversations (1:1 and group) |
| `kazhat_conversation_participants` | Links users to conversations |
| `kazhat_messages` | Chat messages |
| `kazhat_calls` | Video/audio calls with metadata |
| `kazhat_call_participants` | Links users to calls with timing data |

## TURN Server Configuration

For production, you need a TURN server for WebRTC to work behind NATs and firewalls. The default STUN-only configuration works for development but will fail for many users in production.

Options:
- [Twilio Network Traversal](https://www.twilio.com/stun-turn)
- [Xirsys](https://xirsys.com/)
- Self-hosted [coturn](https://github.com/coturn/coturn)

```ruby
config.turn_servers = [
  {
    urls: "turn:turn.example.com:3478",
    username: ENV["TURN_USERNAME"],
    credential: ENV["TURN_CREDENTIAL"]
  },
  {
    urls: "stun:stun.l.google.com:19302"
  }
]
```

## Web UI

Kazhat includes optional HTML views mounted at `/kazhat/`:

- `/kazhat/conversations` — conversation list
- `/kazhat/conversations/:id` — conversation thread
- `/kazhat/calls` — call history
- `/kazhat/calls/:id` — call details with participant breakdown

## License

MIT

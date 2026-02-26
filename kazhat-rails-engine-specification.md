# Kazhat Rails Engine - Complete Implementation Specification

**Version:** 1.0  
**Target Completion:** 8 weeks  
**Team Size:** 15-25 people (internal, desktop-only)  
**Max Concurrent Participants:** 5 people per call

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Namespacing Strategy](#namespacing-strategy)
4. [Database Schema](#database-schema)
5. [Models](#models)
6. [Configuration System](#configuration-system)
7. [Install Generator](#install-generator)
8. [Controllers & API](#controllers--api)
9. [ActionCable Channels](#actioncable-channels)
10. [Frontend Architecture](#frontend-architecture)
11. [View Helpers](#view-helpers)
12. [Data Access Interface](#data-access-interface)
13. [Jobs](#jobs)
14. [Routes](#routes)
15. [8-Week Build Timeline](#8-week-build-timeline)
16. [Testing Strategy](#testing-strategy)
17. [Deployment Considerations](#deployment-considerations)
18. [Troubleshooting Guide](#troubleshooting-guide)

---

## Overview

Kazhat is a mountable Rails engine that adds real-time video calling and messaging to any Rails application. It's designed as a plug-and-play solution with minimal configuration required from the host application.

### Key Features

- **Video & Audio Calls:** 1:1 and group calls (up to 5 participants)
- **Real-time Messaging:** Text chat with typing indicators
- **Call History:** Complete tracking of call duration and participants
- **Floating Popup:** Calls persist in a draggable popup while users navigate
- **Screen Sharing:** Desktop screen sharing capability
- **Keyboard Shortcuts:** Quick access to call controls
- **Desktop Optimized:** Built specifically for desktop browsers

### What the Host App Provides

- A `User` model (or any model responding to `id` and `display_name`)
- A `current_user` method in controllers/channels
- Redis (for ActionCable in production)
- Modern browser environment

---

## Architecture

### Technology Stack

- **Backend:** Rails 7.0+ engine
- **Real-time:** ActionCable with Redis
- **WebRTC:** Mesh topology (peer-to-peer) for up to 5 participants
- **Frontend:** Stimulus controllers + vanilla JavaScript
- **No Build Step:** Works with Importmap (zero-build)

### System Diagram

```
┌─────────────────────────────────────────┐
│  Host Rails App                         │
│  - User model                           │
│  - Authentication                       │
│  - Business logic                       │
└─────────────────────────────────────────┘
            ↓ mounts
┌─────────────────────────────────────────┐
│  Kazhat Engine (/kazhat)                │
│  ┌───────────────────────────────────┐  │
│  │ Backend (Rails)                   │  │
│  │ - Models (conversations, calls)   │  │
│  │ - API Controllers                 │  │
│  │ - ActionCable Channels            │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ Frontend (Stimulus + JS)          │  │
│  │ - WebRTC peer connections         │  │
│  │ - Call popup UI                   │  │
│  │ - Chat interface                  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  Redis (ActionCable)                    │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  TURN Server (for remote users)         │
│  - Twilio / Metered / Self-hosted       │
└─────────────────────────────────────────┘
```

---

## Namespacing Strategy

**Everything is namespaced to avoid conflicts with host applications.**

### Namespacing Rules

| Component | Namespace/Prefix |
|-----------|------------------|
| Database Tables | `kazhat_*` |
| Models | `Kazhat::*` |
| Controllers | `Kazhat::*` |
| Channels | `Kazhat::*` |
| Jobs | `Kazhat::*` |
| Routes | `/kazhat/*` |
| JavaScript | `kazhat/` directory |
| CSS Selectors | `[data-kazhat-*]` |
| LocalStorage Keys | `kazhat_*` |

### Example

```ruby
# NOT this (conflicts possible):
class Call < ApplicationRecord
end

# THIS (properly namespaced):
module Kazhat
  class Call < ApplicationRecord
    self.table_name = 'kazhat_calls'
  end
end
```

---

## Database Schema

### Complete Migration Files

#### 001: Conversations Table

```ruby
class CreateKazhatConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_conversations do |t|
      t.boolean :is_group, default: false, null: false
      t.string :name  # Only for group conversations
      t.timestamps
    end
  end
end
```

#### 002: Conversation Participants Table

```ruby
class CreateKazhatConversationParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_conversation_participants do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :kazhat_conversations }
      t.bigint :user_id, null: false
      t.datetime :last_read_at
      t.timestamps
    end
    
    add_index :kazhat_conversation_participants, 
              [:conversation_id, :user_id], 
              unique: true, 
              name: 'index_kazhat_conv_participants_on_conv_and_user'
    add_index :kazhat_conversation_participants, :user_id
  end
end
```

#### 003: Messages Table

```ruby
class CreateKazhatMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :kazhat_conversations }
      t.bigint :sender_id, null: false
      t.text :body
      t.string :message_type, default: "text", null: false  # text, system, call_started, call_ended
      t.datetime :edited_at
      t.timestamps
    end
    
    add_index :kazhat_messages, [:conversation_id, :created_at]
    add_index :kazhat_messages, :sender_id
  end
end
```

#### 004: Calls Table

```ruby
class CreateKazhatCalls < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_calls do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :kazhat_conversations }
      t.bigint :initiator_id, null: false
      
      # Call metadata
      t.string :call_type, null: false, default: "video"  # audio, video
      t.string :status, null: false, default: "ringing"   # ringing, active, ended, missed, cancelled
      
      # Timing
      t.datetime :started_at      # When first person answered
      t.datetime :ended_at        # When last person left
      t.integer :duration_seconds # Total call duration
      t.integer :ring_duration_seconds  # How long it rang before answer
      
      # Metadata for tracking
      t.integer :max_participants_reached, default: 0
      t.integer :total_participant_seconds, default: 0  # Sum of all participant durations
      
      t.timestamps
    end
    
    add_index :kazhat_calls, :initiator_id
    add_index :kazhat_calls, :status
    add_index :kazhat_calls, :started_at
    add_index :kazhat_calls, [:conversation_id, :created_at]
  end
end
```

#### 005: Call Participants Table

```ruby
class CreateKazhatCallParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_call_participants do |t|
      t.references :call, null: false, foreign_key: { to_table: :kazhat_calls }
      t.bigint :user_id, null: false
      
      # Participant status
      t.string :status, null: false, default: "ringing"  # ringing, joined, left, rejected, missed, busy
      
      # Timing per participant
      t.datetime :rang_at       # When we started ringing this person
      t.datetime :joined_at     # When they clicked "answer"
      t.datetime :left_at       # When they hung up
      t.integer :duration_seconds  # Their personal duration in call
      
      # Quality metrics (optional for v1)
      t.integer :reconnection_count, default: 0
      t.jsonb :quality_stats  # Can store packet loss, jitter, etc.
      
      t.timestamps
    end
    
    add_index :kazhat_call_participants, :user_id
    add_index :kazhat_call_participants, 
              [:call_id, :user_id], 
              unique: true, 
              name: 'index_kazhat_call_participants_on_call_and_user'
    add_index :kazhat_call_participants, :joined_at
  end
end
```

### Entity-Relationship Diagram

```
┌──────────────────────┐
│ kazhat_conversations │
│──────────────────────│
│ id                   │
│ is_group             │
│ name                 │
└──────────────────────┘
          │
          │ has_many
          ├─────────────────┐
          │                 │
          ↓                 ↓
┌──────────────────────┐  ┌──────────────────────┐
│ kazhat_conversation_ │  │ kazhat_messages      │
│      participants    │  │──────────────────────│
│──────────────────────│  │ id                   │
│ id                   │  │ conversation_id      │
│ conversation_id      │  │ sender_id            │
│ user_id              │  │ body                 │
│ last_read_at         │  │ message_type         │
└──────────────────────┘  └──────────────────────┘
          │
          │ has_many
          ↓
┌──────────────────────┐
│ kazhat_calls         │
│──────────────────────│
│ id                   │
│ conversation_id      │
│ initiator_id         │
│ call_type            │
│ status               │
│ started_at           │
│ ended_at             │
│ duration_seconds     │
└──────────────────────┘
          │
          │ has_many
          ↓
┌──────────────────────┐
│ kazhat_call_         │
│    participants      │
│──────────────────────│
│ id                   │
│ call_id              │
│ user_id              │
│ status               │
│ joined_at            │
│ left_at              │
│ duration_seconds     │
└──────────────────────┘
```

---

## Models

### Kazhat::Conversation

```ruby
# app/models/kazhat/conversation.rb
module Kazhat
  class Conversation < ApplicationRecord
    self.table_name = 'kazhat_conversations'
    
    has_many :participants, 
             class_name: 'Kazhat::ConversationParticipant',
             dependent: :destroy
    has_many :messages, 
             class_name: 'Kazhat::Message',
             dependent: :destroy
    has_many :calls,
             class_name: 'Kazhat::Call',
             dependent: :destroy
    
    # Get conversations for a user
    scope :for_user, ->(user_id) {
      joins(:participants)
        .where(kazhat_conversation_participants: { user_id: user_id })
        .distinct
    }
    
    # Find or create 1:1 conversation between two users
    def self.between_users(user1_id, user2_id)
      ids = [user1_id, user2_id].sort
      
      # Find existing 1:1 conversation
      conversation = joins(:participants)
        .where(is_group: false)
        .group('kazhat_conversations.id')
        .having('COUNT(kazhat_conversation_participants.id) = 2')
        .where(kazhat_conversation_participants: { user_id: ids })
        .first
      
      return conversation if conversation
      
      # Create new conversation
      transaction do
        conversation = create!(is_group: false)
        ids.each { |user_id| conversation.participants.create!(user_id: user_id) }
        conversation
      end
    end
    
    # Get other participants (excluding given user)
    def other_participants(user_id)
      participants.where.not(user_id: user_id)
    end
    
    # Unread count for user
    def unread_count_for(user_id)
      participant = participants.find_by(user_id: user_id)
      return 0 unless participant
      
      messages.where('created_at > ?', participant.last_read_at || Time.at(0)).count
    end
    
    # Display name for user (for 1:1 shows other person's name)
    def display_name_for(user_id)
      return name if is_group?
      
      other = other_participants(user_id).first
      other&.user&.kazhat_display_name || "Unknown"
    end
  end
end
```

### Kazhat::ConversationParticipant

```ruby
# app/models/kazhat/conversation_participant.rb
module Kazhat
  class ConversationParticipant < ApplicationRecord
    self.table_name = 'kazhat_conversation_participants'
    
    belongs_to :conversation, class_name: 'Kazhat::Conversation'
    belongs_to :user, class_name: -> { Kazhat.configuration.user_class }
    
    validates :user_id, uniqueness: { scope: :conversation_id }
    
    def mark_as_read!
      update!(last_read_at: Time.current)
    end
  end
end
```

### Kazhat::Message

```ruby
# app/models/kazhat/message.rb
module Kazhat
  class Message < ApplicationRecord
    self.table_name = 'kazhat_messages'
    
    belongs_to :conversation, class_name: 'Kazhat::Conversation'
    belongs_to :sender, class_name: -> { Kazhat.configuration.user_class }, foreign_key: :sender_id
    
    validates :body, presence: true
    
    scope :recent, -> { order(created_at: :desc) }
    scope :for_user, ->(user_id) {
      joins(conversation: :participants)
        .where(kazhat_conversation_participants: { user_id: user_id })
        .distinct
    }
    
    after_create_commit :broadcast_to_conversation
    
    private
    
    def broadcast_to_conversation
      Kazhat::MessageChannel.broadcast_to(
        conversation,
        {
          type: 'new_message',
          message: {
            id: id,
            body: body,
            sender_id: sender_id,
            sender_name: sender.kazhat_display_name,
            created_at: created_at.iso8601
          }
        }
      )
    end
  end
end
```

### Kazhat::Call

```ruby
# app/models/kazhat/call.rb
module Kazhat
  class Call < ApplicationRecord
    self.table_name = 'kazhat_calls'
    
    belongs_to :conversation, class_name: 'Kazhat::Conversation'
    belongs_to :initiator, class_name: -> { Kazhat.configuration.user_class }, foreign_key: :initiator_id
    has_many :call_participants, class_name: 'Kazhat::CallParticipant', dependent: :destroy
    
    validates :call_type, inclusion: { in: %w[audio video] }
    validates :status, inclusion: { in: %w[ringing active ended missed cancelled] }
    
    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: 'ended') }
    scope :for_user, ->(user_id) {
      joins(:call_participants)
        .where(kazhat_call_participants: { user_id: user_id })
        .distinct
    }
    
    # Transition from ringing to active when first person joins
    def mark_as_active!
      return if status == 'active'
      
      update!(
        status: 'active',
        started_at: Time.current,
        ring_duration_seconds: (Time.current - created_at).to_i
      )
    end
    
    # End the call
    def end_call!
      return unless status == 'active'
      
      now = Time.current
      update!(
        status: 'ended',
        ended_at: now,
        duration_seconds: (now - started_at).to_i,
        total_participant_seconds: call_participants.sum(:duration_seconds),
        max_participants_reached: [max_participants_reached, call_participants.where(status: 'joined').count].max
      )
      
      # Mark any still-connected participants as left
      call_participants.where(left_at: nil).each { |p| p.leave!(now) }
    end
    
    # Mark as missed if nobody answered
    def mark_as_missed!
      update!(status: 'missed', ended_at: Time.current)
      call_participants.where(status: 'ringing').update_all(status: 'missed')
    end
    
    # Get active participants
    def active_participants
      call_participants.where(status: 'joined')
    end
    
    # Check if we can add more people
    def can_add_participant?
      active_participants.count < Kazhat.configuration.max_call_participants
    end
    
    # Human-readable duration
    def formatted_duration
      return "—" unless duration_seconds
      
      hours = duration_seconds / 3600
      minutes = (duration_seconds % 3600) / 60
      seconds = duration_seconds % 60
      
      if hours > 0
        "%d:%02d:%02d" % [hours, minutes, seconds]
      else
        "%d:%02d" % [minutes, seconds]
      end
    end
    
    # Average call duration per participant
    def average_participant_duration
      return 0 if call_participants.empty?
      total_participant_seconds / call_participants.count
    end
  end
end
```

### Kazhat::CallParticipant

```ruby
# app/models/kazhat/call_participant.rb
module Kazhat
  class CallParticipant < ApplicationRecord
    self.table_name = 'kazhat_call_participants'
    
    belongs_to :call, class_name: 'Kazhat::Call'
    belongs_to :user, class_name: -> { Kazhat.configuration.user_class }
    
    validates :user_id, uniqueness: { scope: :call_id }
    validates :status, inclusion: { in: %w[ringing joined left rejected missed busy] }
    
    # When participant joins the call
    def join!
      update!(
        status: 'joined',
        joined_at: Time.current
      )
      
      # If this is first person to join, mark call as active
      if call.call_participants.where(status: 'joined').count == 1
        call.mark_as_active!
      end
    end
    
    # When participant leaves the call
    def leave!(time = Time.current)
      return unless status == 'joined'
      
      duration = (time - joined_at).to_i
      update!(
        status: 'left',
        left_at: time,
        duration_seconds: duration
      )
      
      # If everyone left, end the call
      if call.active_participants.none?
        call.end_call!
      end
    end
    
    # Reject incoming call
    def reject!
      update!(status: 'rejected')
    end
    
    # Human-readable duration
    def formatted_duration
      return "—" unless duration_seconds
      
      minutes = duration_seconds / 60
      seconds = duration_seconds % 60
      "%d:%02d" % [minutes, seconds]
    end
  end
end
```

### Kazhat::Chatable Concern (Auto-included in User model)

```ruby
# app/models/concerns/kazhat/chatable.rb
module Kazhat
  module Chatable
    extend ActiveSupport::Concern
    
    included do
      has_many :kazhat_conversation_participants,
               class_name: "Kazhat::ConversationParticipant",
               foreign_key: :user_id,
               dependent: :destroy
      
      has_many :kazhat_conversations,
               through: :kazhat_conversation_participants,
               source: :conversation
      
      has_many :kazhat_sent_messages,
               class_name: "Kazhat::Message",
               foreign_key: :sender_id,
               dependent: :destroy
      
      has_many :kazhat_initiated_calls,
               class_name: "Kazhat::Call",
               foreign_key: :initiator_id,
               dependent: :destroy
      
      has_many :kazhat_call_participations,
               class_name: "Kazhat::CallParticipant",
               foreign_key: :user_id,
               dependent: :destroy
    end
    
    # Override this in your User model if needed
    def kazhat_display_name
      respond_to?(:display_name) ? display_name : (respond_to?(:name) ? name : email)
    end
  end
end
```

---

## Configuration System

### Configuration Class

```ruby
# lib/kazhat/configuration.rb
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
      @call_timeout = 30.seconds
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
  
  class << self
    attr_writer :configuration
    
    def configuration
      @configuration ||= Configuration.new
    end
    
    def configure
      yield(configuration)
    end
    
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
```

### Engine Class

```ruby
# lib/kazhat/engine.rb
module Kazhat
  class Engine < ::Rails::Engine
    isolate_namespace Kazhat
    
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end
    
    initializer "kazhat.assets" do |app|
      app.config.assets.precompile += %w[kazhat/application.js kazhat/application.css]
    end
    
    initializer "kazhat.inject_chatable" do
      ActiveSupport.on_load(:active_record) do
        config = Kazhat.configuration
        if config.user_class.present?
          begin
            user_class = config.user_class.constantize
            user_class.include Kazhat::Chatable unless user_class.include?(Kazhat::Chatable)
          rescue NameError => e
            Rails.logger.warn "Kazhat: Could not find #{config.user_class} class"
          end
        end
      end
    end
    
    initializer "kazhat.action_cable" do
      ActiveSupport.on_load(:action_cable) do
        # Ensure ActionCable is configured
      end
    end
  end
end
```

### Main Module

```ruby
# lib/kazhat.rb
require "kazhat/version"
require "kazhat/engine"
require "kazhat/configuration"
require "kazhat/cable_auth"
require "kazhat/data_access"

module Kazhat
  # Data access methods for host app
  extend DataAccess
end
```

### Example Initializer (Generated)

```ruby
# config/initializers/kazhat.rb (in host app)
Kazhat.configure do |config|
  # Required: Your User model
  config.user_class = "User"
  
  # Required: Method to get current user in controllers/channels
  config.current_user_method = :current_user
  
  # Optional: Call settings
  config.max_call_participants = 5
  config.call_timeout = 30.seconds
  
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
    4 => { width: 640, height: 480, fps: 20 },   # SD for 4-5 people
    5 => { width: 640, height: 480, fps: 20 }
  }
end
```

---

## Install Generator

### Generator Class

```ruby
# lib/generators/kazhat/install_generator.rb
require 'rails/generators'
require 'rails/generators/migration'

module Kazhat
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      
      source_root File.expand_path('templates', __dir__)
      
      def self.next_migration_number(path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end
      
      def copy_initializer
        template "kazhat.rb", "config/initializers/kazhat.rb"
      end
      
      def copy_migrations
        rake "kazhat:install:migrations"
      end
      
      def mount_engine
        route 'mount Kazhat::Engine, at: "/kazhat"'
      end
      
      def inject_cable_auth
        inject_into_file "app/channels/application_cable/connection.rb",
          after: "class Connection < ActionCable::Connection::Base\n" do
          "    include Kazhat::CableAuth\n"
        end
      rescue Errno::ENOENT
        say "⚠️  Could not find app/channels/application_cable/connection.rb", :yellow
        say "   Please add 'include Kazhat::CableAuth' to your Connection class manually", :yellow
      end
      
      def check_redis
        if File.exist?("config/cable.yml") && File.read("config/cable.yml").include?("adapter: async")
          say "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", :yellow
          say "⚠️  ActionCable is using async adapter (in-memory)", :yellow
          say "   For production, you need Redis:", :yellow
          say "   1. Add 'gem \"redis\", \"~> 5.0\"' to Gemfile", :yellow
          say "   2. Update config/cable.yml production adapter to redis", :yellow
          say "   3. Set REDIS_URL in production environment", :yellow
          say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", :yellow
        end
      end
      
      def add_view_helpers
        inject_into_file "app/views/layouts/application.html.erb",
          after: "<head>\n" do
          "    <%= kazhat_meta_tags %>\n"
        end
        
        inject_into_file "app/views/layouts/application.html.erb",
          before: "</body>" do
          "  <%= kazhat_call_container %>\n"
        end
      rescue Errno::ENOENT
        say "⚠️  Could not find app/views/layouts/application.html.erb", :yellow
        say "   Please add view helpers manually", :yellow
      end
      
      def setup_importmap
        if File.exist?("config/importmap.rb")
          append_to_file "config/importmap.rb" do
            "\n# Kazhat\npin \"kazhat\", to: \"kazhat/application.js\"\npin \"@hotwired/stimulus\", to: \"stimulus.min.js\", preload: true\npin \"@rails/actioncable\", to: \"actioncable.esm.js\"\n"
          end
        else
          say "⚠️  Importmap not detected. Using jsbundling? Add Kazhat to your build.", :yellow
        end
      end
      
      def check_user_model
        if File.exist?("app/models/user.rb")
          say "✓ User model found", :green
        else
          say "⚠️  Could not find User model", :yellow
          say "   Update config.user_class in config/initializers/kazhat.rb", :yellow
        end
      end
      
      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
```

### README Template

```ruby
# lib/generators/kazhat/templates/README
================================================================================
                        Kazhat Installation Complete!
================================================================================

Next steps:

1. Run migrations:
   
   rails db:migrate

2. Ensure your User model has a display name method:
   
   # app/models/user.rb
   class User < ApplicationRecord
     def kazhat_display_name
       name # or email, or first_name + last_name, etc.
     end
   end

3. Configure TURN server for production (recommended):
   
   For distributed remote teams, you MUST configure a TURN server.
   Free options:
   - Twilio: https://www.twilio.com/docs/stun-turn
   - Xirsys: https://xirsys.com (free tier available)
   - Metered: https://www.metered.ca
   
   Update config/initializers/kazhat.rb with your credentials.

4. Restart your Rails server:
   
   rails restart

5. Test it out:
   
   - Visit http://localhost:3000/kazhat
   - Or integrate into your app (see docs)

================================================================================
                              Documentation
================================================================================

Access Kazhat in your views:
  
  <%= link_to "Call #{user.name}", "#", 
    data: { 
      controller: "kazhat--quick-call",
      action: "click->kazhat--quick-call#call",
      user_id: user.id 
    } %>

Access call data in your app:

  # Get user's call history
  calls = Kazhat.calls_for_user(user.id, from: 1.month.ago)
  
  # Get user stats
  stats = Kazhat.user_stats(user.id, period: :month)
  
  # Get team stats
  team_stats = Kazhat.team_stats(from: 1.month.ago)

Full documentation: https://github.com/yourusername/kazhat

Need help? Open an issue: https://github.com/yourusername/kazhat/issues

================================================================================
```

---

## Controllers & API

### Base Controller

```ruby
# app/controllers/kazhat/api/v1/base_controller.rb
module Kazhat
  module Api
    module V1
      class BaseController < ActionController::API
        before_action :authenticate_user!
        
        private
        
        def current_user
          @current_user ||= send(Kazhat.configuration.current_user_method)
        end
        
        def authenticate_user!
          render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
        end
        
        def pagination_meta(collection)
          {
            current_page: collection.current_page,
            next_page: collection.next_page,
            prev_page: collection.prev_page,
            total_pages: collection.total_pages,
            total_count: collection.total_count
          }
        end
      end
    end
  end
end
```

### Conversations Controller

```ruby
# app/controllers/kazhat/api/v1/conversations_controller.rb
module Kazhat
  module Api
    module V1
      class ConversationsController < BaseController
        # GET /kazhat/api/v1/conversations
        def index
          conversations = Kazhat::Conversation
            .for_user(current_user.id)
            .includes(:participants, :messages)
            .order('kazhat_messages.created_at DESC')
          
          render json: {
            conversations: conversations.map { |c| serialize_conversation(c) }
          }
        end
        
        # POST /kazhat/api/v1/conversations
        def create
          if params[:participant_ids].length == 1
            # 1:1 conversation
            other_user_id = params[:participant_ids].first
            conversation = Kazhat::Conversation.between_users(current_user.id, other_user_id)
          else
            # Group conversation
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
        
        # GET /kazhat/api/v1/conversations/:id
        def show
          conversation = Kazhat::Conversation.find(params[:id])
          authorize_conversation!(conversation)
          
          render json: { conversation: serialize_conversation(conversation) }
        end
        
        private
        
        def serialize_conversation(conversation)
          last_message = conversation.messages.last
          
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
          render json: { error: 'Not authorized' }, status: :forbidden unless participant
        end
      end
    end
  end
end
```

### Messages Controller

```ruby
# app/controllers/kazhat/api/v1/messages_controller.rb
module Kazhat
  module Api
    module V1
      class MessagesController < BaseController
        before_action :set_conversation
        
        # GET /kazhat/api/v1/conversations/:conversation_id/messages
        def index
          messages = @conversation.messages
            .includes(:sender)
            .order(created_at: :desc)
            .page(params[:page])
            .per(params[:per_page] || 50)
          
          render json: {
            messages: messages.map { |m| serialize_message(m) },
            meta: pagination_meta(messages)
          }
        end
        
        # POST /kazhat/api/v1/conversations/:conversation_id/messages
        def create
          message = @conversation.messages.create!(
            sender: current_user,
            body: params[:body]
          )
          
          render json: { message: serialize_message(message) }, status: :created
        end
        
        # POST /kazhat/api/v1/conversations/:conversation_id/messages/read
        def mark_as_read
          participant = @conversation.participants.find_by!(user: current_user)
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
          render json: { error: 'Not authorized' }, status: :forbidden unless participant
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
```

### Calls Controller

```ruby
# app/controllers/kazhat/api/v1/calls_controller.rb
module Kazhat
  module Api
    module V1
      class CallsController < BaseController
        # GET /kazhat/api/v1/calls
        def index
          calls = Kazhat::Call.for_user(current_user.id)
                      .includes(:initiator, :call_participants, call_participants: :user)
                      .recent
                      .page(params[:page])
                      .per(params[:per_page] || 20)
          
          # Optional filters
          calls = calls.where(call_type: params[:call_type]) if params[:call_type]
          calls = calls.where(status: params[:status]) if params[:status]
          calls = calls.where("started_at >= ?", params[:from_date]) if params[:from_date]
          calls = calls.where("started_at <= ?", params[:to_date]) if params[:to_date]
          
          render json: {
            calls: calls.map { |call| serialize_call(call) },
            meta: pagination_meta(calls)
          }
        end
        
        # GET /kazhat/api/v1/calls/:id
        def show
          call = Kazhat::Call.find(params[:id])
          authorize_call_access!(call)
          
          render json: {
            call: serialize_call_detailed(call)
          }
        end
        
        # POST /kazhat/api/v1/calls
        def create
          conversation = if params[:conversation_id]
            Kazhat::Conversation.find(params[:conversation_id])
          else
            Kazhat::Conversation.between_users(current_user.id, params[:user_id])
          end
          
          call = conversation.calls.create!(
            initiator: current_user,
            call_type: params[:call_type] || 'video',
            status: 'ringing'
          )
          
          # Create participant for initiator
          call.call_participants.create!(
            user: current_user,
            status: 'joined',
            rang_at: Time.current,
            joined_at: Time.current
          )
          
          # Ring other participants
          conversation.other_participants(current_user.id).each do |participant|
            call.call_participants.create!(
              user_id: participant.user_id,
              status: 'ringing',
              rang_at: Time.current
            )
            
            # Notify them
            Kazhat::NotificationChannel.notify_incoming_call(participant.user, call)
          end
          
          render json: { call: serialize_call(call) }, status: :created
        end
        
        # GET /kazhat/api/v1/calls/stats
        def stats
          user_calls = Kazhat::Call.for_user(current_user.id).completed
          
          render json: {
            stats: {
              total_calls: user_calls.count,
              total_duration: user_calls.sum(:duration_seconds),
              average_duration: user_calls.average(:duration_seconds)&.to_i || 0,
              total_video_calls: user_calls.where(call_type: 'video').count,
              total_audio_calls: user_calls.where(call_type: 'audio').count,
              
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
          serialize_call(call).merge({
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
          })
        end
        
        def frequent_call_partners(user_id, limit: 5)
          Kazhat::Call.joins(:call_participants)
              .where(kazhat_call_participants: { user_id: user_id })
              .where.not(initiator_id: user_id)
              .group("kazhat_calls.initiator_id")
              .order("COUNT(*) DESC")
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
          render json: { error: "Not authorized" }, status: :forbidden unless participant
        end
      end
    end
  end
end
```

---

## ActionCable Channels

### Cable Authentication

```ruby
# lib/kazhat/cable_auth.rb
module Kazhat
  module CableAuth
    extend ActiveSupport::Concern
    
    included do
      identified_by :current_user
      
      def connect
        self.current_user = find_verified_user
        logger.add_tags "Kazhat", "User #{current_user.id}"
      end
      
      private
      
      def find_verified_user
        user = find_user_from_env || find_user_from_session
        reject_unauthorized_connection unless user
        user
      end
      
      def find_user_from_env
        # Try Warden (Devise)
        env['warden']&.user
      end
      
      def find_user_from_session
        # Try session
        user_id = request.session[:user_id]
        return nil unless user_id
        Kazhat.configuration.user_class_constant.find_by(id: user_id)
      end
    end
  end
end
```

### Call Channel

```ruby
# app/channels/kazhat/call_channel.rb
module Kazhat
  class CallChannel < ApplicationCable::Channel
    def subscribed
      @call = Kazhat::Call.find(params[:call_id])
      @participant = @call.call_participants.find_or_create_by!(user: current_user) do |p|
        p.rang_at = Time.current
        p.status = 'ringing'
      end
      
      # Check participant limit
      unless @call.can_add_participant?
        transmit({ type: 'error', message: 'Call is full' })
        reject
        return
      end
      
      stream_for @call
    end
    
    def answer(data)
      @participant.join!
      
      broadcast_to_others({
        type: 'participant_joined',
        participant: serialize_participant(@participant),
        participants: all_participants
      })
      
      # Send existing participants to new joiner
      transmit({
        type: 'existing_participants',
        participants: other_participants
      })
    end
    
    def signal(data)
      Kazhat::CallChannel.broadcast_to(@call, {
        type: 'signal',
        from_peer_id: @participant.id,
        signal: data['signal'],
        target_peer_id: data['target_peer_id']
      })
    end
    
    def reject(data)
      @participant.reject!
      
      broadcast_to_others({
        type: 'participant_rejected',
        participant_id: @participant.user_id
      })
    end
    
    def unsubscribed
      return unless @participant
      
      case @participant.status
      when 'ringing'
        @participant.update!(status: 'missed')
      when 'joined'
        @participant.leave!
      end
      
      broadcast_to_others({
        type: 'participant_left',
        participant_id: @participant.user_id,
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
      @call.call_participants.where.not(id: @participant.id).map { |p| serialize_participant(p) }
    end
    
    def broadcast_to_others(data)
      Kazhat::CallChannel.broadcast_to(@call, data)
    end
  end
end
```

### Message Channel

```ruby
# app/channels/kazhat/message_channel.rb
module Kazhat
  class MessageChannel < ApplicationCable::Channel
    def subscribed
      @conversation = Kazhat::Conversation.find(params[:conversation_id])
      
      # Verify user is participant
      @participant = @conversation.participants.find_by(user: current_user)
      reject unless @participant
      
      stream_for @conversation
    end
    
    def typing(data)
      Kazhat::MessageChannel.broadcast_to(@conversation, {
        type: 'typing',
        user_id: current_user.id,
        user_name: current_user.kazhat_display_name,
        is_typing: data['is_typing']
      })
    end
    
    def unsubscribed
      # Mark as not typing when user disconnects
      Kazhat::MessageChannel.broadcast_to(@conversation, {
        type: 'typing',
        user_id: current_user.id,
        is_typing: false
      })
    end
  end
end
```

### Notification Channel

```ruby
# app/channels/kazhat/notification_channel.rb
module Kazhat
  class NotificationChannel < ApplicationCable::Channel
    def subscribed
      stream_for current_user
    end
    
    # Class method to broadcast notifications
    def self.notify_incoming_call(user, call)
      broadcast_to(user, {
        type: 'incoming_call',
        call: {
          id: call.id,
          conversation_id: call.conversation_id,
          initiator: {
            id: call.initiator.id,
            name: call.initiator.kazhat_display_name
          },
          call_type: call.call_type,
          created_at: call.created_at.iso8601
        }
      })
    end
    
    def self.notify_new_message(user, message)
      broadcast_to(user, {
        type: 'new_message',
        message: {
          id: message.id,
          conversation_id: message.conversation_id,
          sender: {
            id: message.sender_id,
            name: message.sender.kazhat_display_name
          },
          body: message.body,
          created_at: message.created_at.iso8601
        }
      })
    end
  end
end
```

---

## Frontend Architecture

### Directory Structure

```
app/assets/javascripts/kazhat/
├── application.js                 # Entry point, registers all controllers
├── controllers/
│   ├── call_controller.js         # Main call logic + WebRTC mesh
│   ├── call_controls_controller.js # Mute/video/screen/hangup buttons
│   ├── call_popup_controller.js   # Draggable popup, fullscreen, minimize
│   ├── video_grid_controller.js   # Video element management
│   ├── call_timer_controller.js   # Real-time call duration display
│   ├── incoming_call_controller.js # Incoming call notification toast
│   ├── chat_controller.js         # Message thread
│   ├── conversation_list_controller.js # Conversation sidebar
│   ├── typing_controller.js       # Typing indicator
│   └── notification_controller.js # Global notifications
├── lib/
│   ├── cable.js                   # ActionCable consumer factory
│   ├── webrtc.js                  # WebRTC utilities (createPC, createOffer, etc)
│   ├── call_state.js              # Simple state management
│   └── api.js                     # Fetch wrapper for API calls
└── application.css                # Minimal scoped styles
```

### Application Entry Point

```javascript
// app/assets/javascripts/kazhat/application.js

import { Application } from "@hotwired/stimulus"
import CallController from "./controllers/call_controller"
import CallControlsController from "./controllers/call_controls_controller"
import CallPopupController from "./controllers/call_popup_controller"
import VideoGridController from "./controllers/video_grid_controller"
import CallTimerController from "./controllers/call_timer_controller"
import IncomingCallController from "./controllers/incoming_call_controller"
import ChatController from "./controllers/chat_controller"
import ConversationListController from "./controllers/conversation_list_controller"
import TypingController from "./controllers/typing_controller"
import NotificationController from "./controllers/notification_controller"

window.Stimulus = Application.start()

// Register all controllers under kazhat namespace
Stimulus.register("kazhat--call", CallController)
Stimulus.register("kazhat--call-controls", CallControlsController)
Stimulus.register("kazhat--call-popup", CallPopupController)
Stimulus.register("kazhat--video-grid", VideoGridController)
Stimulus.register("kazhat--call-timer", CallTimerController)
Stimulus.register("kazhat--incoming-call", IncomingCallController)
Stimulus.register("kazhat--chat", ChatController)
Stimulus.register("kazhat--conversation-list", ConversationListController)
Stimulus.register("kazhat--typing", TypingController)
Stimulus.register("kazhat--notification", NotificationController)
```

### WebRTC Library

```javascript
// app/assets/javascripts/kazhat/lib/webrtc.js

export function getMediaConstraints(participantCount) {
  const quality = window.kazhatConfig?.videoQuality || {
    2: { width: 1280, height: 720, frameRate: 30 },
    3: { width: 960, height: 540, frameRate: 24 },
    4: { width: 640, height: 480, frameRate: 20 }
  }
  
  const level = Math.min(participantCount, 4)
  
  return {
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true
    },
    video: quality[level] || quality[4]
  }
}

export function getTurnServers() {
  try {
    const metaTag = document.querySelector('meta[name="kazhat-turn-servers"]')
    return metaTag ? JSON.parse(metaTag.content) : [{ urls: 'stun:stun.l.google.com:19302' }]
  } catch (e) {
    console.error('Failed to parse TURN servers:', e)
    return [{ urls: 'stun:stun.l.google.com:19302' }]
  }
}

export function createPeerConnection(localStream, callbacks = {}) {
  const config = {
    iceServers: getTurnServers()
  }
  
  const pc = new RTCPeerConnection(config)
  
  // Add local tracks to peer connection
  if (localStream) {
    localStream.getTracks().forEach(track => {
      pc.addTrack(track, localStream)
    })
  }
  
  // Handle incoming remote stream
  pc.ontrack = (event) => {
    if (callbacks.onTrack) {
      callbacks.onTrack(event.streams[0])
    }
  }
  
  // Handle ICE candidates
  pc.onicecandidate = (event) => {
    if (event.candidate && callbacks.onIceCandidate) {
      callbacks.onIceCandidate(event.candidate)
    }
  }
  
  // Monitor connection state
  pc.onconnectionstatechange = () => {
    if (callbacks.onConnectionStateChange) {
      callbacks.onConnectionStateChange(pc.connectionState)
    }
  }
  
  pc.oniceconnectionstatechange = () => {
    if (callbacks.onIceConnectionStateChange) {
      callbacks.onIceConnectionStateChange(pc.iceConnectionState)
    }
  }
  
  return pc
}

export async function createOffer(pc) {
  const offer = await pc.createOffer()
  await pc.setLocalDescription(offer)
  return offer
}

export async function createAnswer(pc) {
  const answer = await pc.createAnswer()
  await pc.setLocalDescription(answer)
  return answer
}

export async function handleOffer(pc, offer) {
  await pc.setRemoteDescription(new RTCSessionDescription(offer))
  return await createAnswer(pc)
}

export async function handleAnswer(pc, answer) {
  await pc.setRemoteDescription(new RTCSessionDescription(answer))
}

export async function handleIceCandidate(pc, candidate) {
  if (candidate) {
    await pc.addIceCandidate(new RTCIceCandidate(candidate))
  }
}
```

### Call State Management

```javascript
// app/assets/javascripts/kazhat/lib/call_state.js

const state = {
  callState: 'idle',       // idle | connecting | ringing_outgoing | ringing_incoming | connected | ended
  callId: null,
  conversationId: null,
  localStream: null,
  remotePeers: new Map(),  // Map<peerId, { pc, stream, participant }>
  audioEnabled: true,
  videoEnabled: true,
  screenSharing: false,
  screenStream: null,
  popupPosition: { bottom: 20, right: 20 },
  isFullscreen: false,
  isMinimized: false,
  participants: []
}

const listeners = new Set()

export const callState = {
  get: () => state,
  
  set: (patch) => {
    Object.assign(state, patch)
    listeners.forEach(fn => fn(state))
  },
  
  subscribe: (fn) => {
    listeners.add(fn)
    fn(state) // Call immediately with current state
    return () => listeners.delete(fn)
  },
  
  reset: () => {
    // Stop all media
    if (state.localStream) {
      state.localStream.getTracks().forEach(track => track.stop())
    }
    if (state.screenStream) {
      state.screenStream.getTracks().forEach(track => track.stop())
    }
    
    // Close all peer connections
    state.remotePeers.forEach(({ pc }) => pc.close())
    
    Object.assign(state, {
      callState: 'idle',
      callId: null,
      conversationId: null,
      localStream: null,
      remotePeers: new Map(),
      audioEnabled: true,
      videoEnabled: true,
      screenSharing: false,
      screenStream: null,
      participants: []
    })
    
    listeners.forEach(fn => fn(state))
  }
}
```

### Cable Wrapper

```javascript
// app/assets/javascripts/kazhat/lib/cable.js

import { createConsumer } from "@rails/actioncable"

let consumer = null

export function getConsumer() {
  if (!consumer) {
    const wsUrl = document.querySelector('meta[name="action-cable-url"]')?.content
    consumer = createConsumer(wsUrl)
  }
  return consumer
}

export function createSubscription(channel, params, callbacks) {
  return getConsumer().subscriptions.create(
    { channel: `Kazhat::${channel}`, ...params },
    callbacks
  )
}

export function disconnectConsumer() {
  if (consumer) {
    consumer.disconnect()
    consumer = null
  }
}
```

### API Wrapper

```javascript
// app/assets/javascripts/kazhat/lib/api.js

const API_BASE = '/kazhat/api/v1'

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content
}

export const api = {
  async get(path) {
    const response = await fetch(`${API_BASE}${path}`, {
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    return response
  },
  
  async post(path, data = {}) {
    const response = await fetch(`${API_BASE}${path}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      },
      body: JSON.stringify(data)
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    return response
  },
  
  async patch(path, data = {}) {
    const response = await fetch(`${API_BASE}${path}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      },
      body: JSON.stringify(data)
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    return response
  },
  
  async delete(path) {
    const response = await fetch(`${API_BASE}${path}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken()
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }
    
    return response
  }
}
```

### Main Call Controller (Simplified)

```javascript
// app/assets/javascripts/kazhat/controllers/call_controller.js

import { Controller } from "@hotwired/stimulus"
import { callState } from "../lib/call_state"
import { createSubscription } from "../lib/cable"
import { 
  getMediaConstraints, 
  createPeerConnection, 
  createOffer, 
  handleOffer, 
  handleAnswer, 
  handleIceCandidate 
} from "../lib/webrtc"

export default class extends Controller {
  static values = {
    callId: String,
    userId: Number
  }
  
  static targets = ["popup", "videoGrid"]
  
  async connect() {
    await this.initializeCall()
  }
  
  disconnect() {
    this.cleanup()
  }
  
  async initializeCall() {
    try {
      // Get local media stream
      const constraints = getMediaConstraints(2)
      const stream = await navigator.mediaDevices.getUserMedia(constraints)
      
      callState.set({ 
        localStream: stream,
        callId: this.callIdValue,
        callState: 'connecting'
      })
      
      // Subscribe to call channel
      this.subscription = createSubscription('CallChannel', 
        { call_id: this.callIdValue },
        {
          connected: () => this.handleConnected(),
          received: (data) => this.handleMessage(data),
          disconnected: () => this.handleDisconnected()
        }
      )
      
    } catch (error) {
      console.error('Failed to initialize call:', error)
      this.showError('Could not access camera/microphone')
    }
  }
  
  handleConnected() {
    // Send answer to join the call
    this.subscription.perform('answer', {})
    callState.set({ callState: 'connected' })
  }
  
  async handleMessage(data) {
    switch (data.type) {
      case 'existing_participants':
        // Connect to all existing participants (we initiate)
        for (const participant of data.participants) {
          await this.connectToParticipant(participant, true)
        }
        break
        
      case 'participant_joined':
        // New participant - they will send us an offer
        break
        
      case 'signal':
        await this.handleSignal(data)
        break
        
      case 'participant_left':
        this.removeParticipant(data.participant_id)
        break
        
      case 'error':
        this.showError(data.message)
        break
    }
  }
  
  async connectToParticipant(participant, shouldCreateOffer) {
    const peerId = participant.peer_id
    
    if (callState.get().remotePeers.has(peerId)) {
      return // Already connected
    }
    
    const pc = createPeerConnection(callState.get().localStream, {
      onTrack: (stream) => {
        this.addRemoteVideo(peerId, participant, stream)
      },
      onIceCandidate: (candidate) => {
        this.subscription.perform('signal', {
          target_peer_id: peerId,
          signal: { type: 'ice-candidate', candidate }
        })
      },
      onConnectionStateChange: (state) => {
        console.log(`Connection to ${participant.name}: ${state}`)
        if (state === 'failed' || state === 'disconnected') {
          this.handleConnectionFailure(peerId, participant)
        }
      }
    })
    
    callState.get().remotePeers.set(peerId, { pc, participant })
    
    if (shouldCreateOffer) {
      const offer = await createOffer(pc)
      this.subscription.perform('signal', {
        target_peer_id: peerId,
        signal: { type: 'offer', offer }
      })
    }
  }
  
  async handleSignal(data) {
    const { from_peer_id, signal } = data
    
    let peerData = callState.get().remotePeers.get(from_peer_id)
    
    switch (signal.type) {
      case 'offer':
        if (!peerData) {
          // Create new peer connection for incoming offer
          const pc = createPeerConnection(callState.get().localStream, {
            onTrack: (stream) => this.addRemoteVideo(from_peer_id, { peer_id: from_peer_id }, stream),
            onIceCandidate: (candidate) => {
              this.subscription.perform('signal', {
                target_peer_id: from_peer_id,
                signal: { type: 'ice-candidate', candidate }
              })
            }
          })
          peerData = { pc }
          callState.get().remotePeers.set(from_peer_id, peerData)
        }
        
        const answer = await handleOffer(peerData.pc, signal.offer)
        this.subscription.perform('signal', {
          target_peer_id: from_peer_id,
          signal: { type: 'answer', answer }
        })
        break
        
      case 'answer':
        if (peerData) {
          await handleAnswer(peerData.pc, signal.answer)
        }
        break
        
      case 'ice-candidate':
        if (peerData) {
          await handleIceCandidate(peerData.pc, signal.candidate)
        }
        break
    }
  }
  
  addRemoteVideo(peerId, participant, stream) {
    // Dispatch event to video grid controller
    this.dispatch('addRemoteStream', { 
      detail: { peerId, participant, stream } 
    })
  }
  
  removeParticipant(participantId) {
    // Find and remove peer by user ID
    for (const [peerId, data] of callState.get().remotePeers.entries()) {
      if (data.participant?.id === participantId) {
        data.pc.close()
        callState.get().remotePeers.delete(peerId)
        
        this.dispatch('removeParticipant', { 
          detail: { participantId } 
        })
      }
    }
  }
  
  handleConnectionFailure(peerId, participant) {
    console.log('Connection failed, attempting reconnect...')
    // TODO: Implement reconnection logic
  }
  
  handleDisconnected() {
    console.log('Disconnected from call channel')
  }
  
  cleanup() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    
    callState.reset()
  }
  
  showError(message) {
    // TODO: Better error UI
    alert(message)
  }
}
```

---

## View Helpers

```ruby
# app/helpers/kazhat/application_helper.rb
module Kazhat
  module ApplicationHelper
    def kazhat_meta_tags
      tags = []
      
      # API base URL
      tags << tag.meta(name: 'kazhat-api-url', content: kazhat.api_v1_conversations_url)
      
      # ActionCable URL
      tags << tag.meta(name: 'action-cable-url', content: action_cable_url)
      
      # TURN servers
      tags << tag.meta(name: 'kazhat-turn-servers', content: Kazhat.configuration.turn_servers.to_json)
      
      # Video quality settings
      tags << tag.meta(name: 'kazhat-video-quality', content: Kazhat.configuration.video_quality.to_json)
      
      # Current user ID
      if current_user
        tags << tag.meta(name: 'kazhat-user-id', content: current_user.id)
      end
      
      # Max participants
      tags << tag.meta(name: 'kazhat-max-participants', content: Kazhat.configuration.max_call_participants)
      
      safe_join(tags, "\n")
    end
    
    def kazhat_call_container
      content_tag :div, 
        '', 
        id: 'kazhat-container',
        data: { 
          controller: 'kazhat--notification',
          kazhat_notification_user_id_value: current_user&.id
        }
    end
    
    def kazhat_quick_call_button(user, **options)
      button_text = options.delete(:text) || "Call #{user.kazhat_display_name}"
      call_type = options.delete(:call_type) || 'video'
      
      link_to button_text, '#',
        data: {
          controller: 'kazhat--quick-call',
          action: 'click->kazhat--quick-call#call',
          kazhat_quick_call_user_id_value: user.id,
          kazhat_quick_call_call_type_value: call_type
        },
        **options
    end
  end
end
```

---

## Data Access Interface

```ruby
# lib/kazhat/data_access.rb
module Kazhat
  module DataAccess
    # Get all calls for a user in a date range
    def calls_for_user(user_id, from: nil, to: nil)
      calls = Kazhat::Call.for_user(user_id)
                          .includes(:initiator, :call_participants, call_participants: :user)
      calls = calls.where('started_at >= ?', from) if from
      calls = calls.where('started_at <= ?', to) if to
      calls
    end
    
    # Get all messages for a user
    def messages_for_user(user_id, from: nil, to: nil)
      messages = Kazhat::Message.for_user(user_id)
                                .includes(:sender, :conversation)
      messages = messages.where('created_at >= ?', from) if from
      messages = messages.where('created_at <= ?', to) if to
      messages
    end
    
    # Get aggregated stats for a single user
    def user_stats(user_id, period: :all_time)
      from_date = case period
        when :week then 1.week.ago
        when :month then 1.month.ago
        when :year then 1.year.ago
        else nil
      end
      
      calls = calls_for_user(user_id, from: from_date).completed
      messages = messages_for_user(user_id, from: from_date)
      
      {
        period: period,
        calls: {
          total: calls.count,
          total_duration_seconds: calls.sum(:duration_seconds),
          average_duration_seconds: calls.average(:duration_seconds)&.to_i || 0,
          video_calls: calls.where(call_type: 'video').count,
          audio_calls: calls.where(call_type: 'audio').count
        },
        messages: {
          total_sent: messages.where(sender_id: user_id).count,
          total_received: messages.where.not(sender_id: user_id).count,
          conversations: Kazhat::Conversation.for_user(user_id).count
        }
      }
    end
    
    # Get team-wide stats
    def team_stats(from: nil, to: nil)
      calls = Kazhat::Call.completed
      calls = calls.where('started_at >= ?', from) if from
      calls = calls.where('started_at <= ?', to) if to
      
      messages = Kazhat::Message.all
      messages = messages.where('created_at >= ?', from) if from
      messages = messages.where('created_at <= ?', to) if to
      
      {
        calls: {
          total: calls.count,
          total_duration_seconds: calls.sum(:duration_seconds),
          average_duration_seconds: calls.average(:duration_seconds)&.to_i || 0,
          unique_users: Kazhat::CallParticipant.joins(:call)
                          .merge(calls)
                          .distinct
                          .count(:user_id)
        },
        messages: {
          total: messages.count,
          unique_senders: messages.distinct.count(:sender_id),
          active_conversations: Kazhat::Conversation
                                  .joins(:messages)
                                  .merge(messages)
                                  .distinct
                                  .count
        }
      }
    end
    
    # Get call history with duration for export to host app
    def call_history_for_export(from: nil, to: nil)
      calls = Kazhat::Call.completed
                          .includes(:initiator, :call_participants, call_participants: :user)
      calls = calls.where('started_at >= ?', from) if from
      calls = calls.where('started_at <= ?', to) if to
      
      calls.map do |call|
        {
          call_id: call.id,
          initiator_id: call.initiator_id,
          initiator_name: call.initiator.kazhat_display_name,
          call_type: call.call_type,
          started_at: call.started_at,
          ended_at: call.ended_at,
          duration_seconds: call.duration_seconds,
          participants: call.call_participants.map do |p|
            {
              user_id: p.user_id,
              user_name: p.user.kazhat_display_name,
              joined_at: p.joined_at,
              left_at: p.left_at,
              duration_seconds: p.duration_seconds
            }
          end
        }
      end
    end
  end
end
```

### Usage Examples

```ruby
# In host app controllers or services

# Get user's call history for the past month
calls = Kazhat.calls_for_user(current_user.id, from: 1.month.ago)

# Get user stats for reporting
stats = Kazhat.user_stats(current_user.id, period: :month)
# => {
#   period: :month,
#   calls: { total: 45, total_duration_seconds: 12600, ... },
#   messages: { total_sent: 230, ... }
# }

# Get team-wide stats for admin dashboard
team_stats = Kazhat.team_stats(from: 1.month.ago, to: Date.today)

# Export call history for billing or time tracking
call_data = Kazhat.call_history_for_export(from: 1.month.ago)
call_data.each do |call|
  TimeEntry.create!(
    user_id: call[:initiator_id],
    duration: call[:duration_seconds],
    description: "Video call with #{call[:participants].map { |p| p[:user_name] }.join(', ')}"
  )
end
```

---

## Jobs

### Call Cleanup Job

```ruby
# app/jobs/kazhat/call_cleanup_job.rb
module Kazhat
  class CallCleanupJob < ApplicationJob
    queue_as :default
    
    def perform
      # End calls that have been active for more than 8 hours (likely stale)
      Call.where(status: 'active')
          .where("started_at < ?", 8.hours.ago)
          .find_each(&:end_call!)
      
      # Mark ringing calls as missed after timeout
      Call.where(status: 'ringing')
          .where("created_at < ?", Kazhat.configuration.call_timeout.ago)
          .find_each(&:mark_as_missed!)
    end
  end
end
```

### Schedule (using whenever or sidekiq-cron)

```ruby
# config/schedule.rb (if using whenever)
every 5.minutes do
  runner "Kazhat::CallCleanupJob.perform_now"
end

# OR for Sidekiq (config/initializers/sidekiq.rb)
Sidekiq::Cron::Job.create(
  name: 'Kazhat Call Cleanup',
  cron: '*/5 * * * *',
  class: 'Kazhat::CallCleanupJob'
)
```

---

## Routes

```ruby
# config/routes.rb (in engine)
Kazhat::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :conversations, only: [:index, :create, :show] do
        resources :messages, only: [:index, :create] do
          post :read, on: :collection, action: :mark_as_read
        end
      end
      
      resources :calls, only: [:index, :show, :create] do
        get :stats, on: :collection
      end
    end
  end
  
  # Optional: UI routes (if you want to provide default views)
  resources :conversations, only: [:index, :show]
  resources :calls, only: [:index, :show]
  
  root to: 'conversations#index'
end
```

---

## 8-Week Build Timeline

### Week 1-2: Foundation

**Week 1: Gem Scaffold & Database**

- Day 1-2: Create gem structure, gemspec, basic engine setup
- Day 3-5: Database migrations, model scaffolds
- Day 6-7: Core model implementations with associations

**Deliverable:** Database schema + models working

**Week 2: Configuration & Install**

- Day 8-9: Configuration system, engine initializers
- Day 10-12: Install generator with smart detection
- Day 13-14: Data access interface for host apps

**Deliverable:** Complete installation system

---

### Week 3-5: Video Calling

**Week 3: Basic WebRTC**

- Day 15-17: ActionCable channels (Call, Message, Notification)
- Day 18-21: Frontend WebRTC library, basic 1:1 video calls

**Deliverable:** Working 1:1 video calls

**Week 4: Multi-party Calls**

- Day 22-24: Multi-party mesh logic (up to 5 people)
- Day 25-28: Call controls (mute, video, screen share, hangup)

**Deliverable:** 5-person calls with controls

**Week 5: Call Polish**

- Day 29-31: Popup UI (draggable, fullscreen, minimize)
- Day 32-35: Error handling, reconnection, keyboard shortcuts

**Deliverable:** Polished call experience

---

### Week 6-7: Messaging

**Week 6: Messaging Backend**

- Day 36-39: Message API, real-time channels
- Day 40-42: Typing indicators, unread counts

**Deliverable:** Working messaging backend

**Week 7: Messaging UI**

- Day 43-45: Chat interface (Stimulus controller)
- Day 46-47: Conversation list
- Day 48-49: Integration polish, view helpers

**Deliverable:** Complete messaging system

---

### Week 8: Final Polish & Documentation

**Day 50-52: Testing**

- Write model specs
- Write channel specs
- Write controller specs
- Integration tests

**Day 53-55: Documentation**

- README with installation instructions
- API documentation
- Configuration guide
- Troubleshooting guide
- Example integration

**Day 56: Example App & Release**

- Create demo Rails app
- Deploy example to Heroku/Render
- Final gem polish
- Release v1.0

**Deliverable:** Production-ready v1.0

---

## Testing Strategy

### Model Tests

```ruby
# spec/models/kazhat/call_spec.rb
RSpec.describe Kazhat::Call, type: :model do
  describe 'associations' do
    it { should belong_to(:conversation) }
    it { should belong_to(:initiator) }
    it { should have_many(:call_participants) }
  end
  
  describe 'validations' do
    it { should validate_inclusion_of(:call_type).in_array(%w[audio video]) }
    it { should validate_inclusion_of(:status).in_array(%w[ringing active ended missed cancelled]) }
  end
  
  describe '#mark_as_active!' do
    it 'transitions from ringing to active' do
      call = create(:kazhat_call, status: 'ringing')
      call.mark_as_active!
      expect(call.status).to eq('active')
    end
    
    it 'records started_at timestamp' do
      call = create(:kazhat_call, status: 'ringing')
      expect { call.mark_as_active! }.to change { call.started_at }.from(nil)
    end
    
    it 'calculates ring_duration_seconds' do
      call = create(:kazhat_call, status: 'ringing', created_at: 10.seconds.ago)
      call.mark_as_active!
      expect(call.ring_duration_seconds).to be_within(2).of(10)
    end
  end
  
  describe '#end_call!' do
    it 'transitions to ended status' do
      call = create(:kazhat_call, status: 'active')
      call.end_call!
      expect(call.status).to eq('ended')
    end
    
    it 'calculates total duration' do
      call = create(:kazhat_call, status: 'active', started_at: 5.minutes.ago)
      call.end_call!
      expect(call.duration_seconds).to be_within(5).of(300)
    end
  end
  
  describe '#can_add_participant?' do
    it 'allows up to max participants' do
      call = create(:kazhat_call)
      4.times { create(:kazhat_call_participant, call: call, status: 'joined') }
      expect(call.can_add_participant?).to be true
    end
    
    it 'blocks when at capacity' do
      call = create(:kazhat_call)
      5.times { create(:kazhat_call_participant, call: call, status: 'joined') }
      expect(call.can_add_participant?).to be false
    end
  end
end
```

### Channel Tests

```ruby
# spec/channels/kazhat/call_channel_spec.rb
RSpec.describe Kazhat::CallChannel, type: :channel do
  let(:user) { create(:user) }
  let(:call) { create(:kazhat_call) }
  
  before do
    stub_connection current_user: user
  end
  
  describe '#subscribed' do
    it 'streams from the call' do
      subscribe call_id: call.id
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(call)
    end
    
    it 'creates a call participant' do
      expect {
        subscribe call_id: call.id
      }.to change { call.call_participants.count }.by(1)
    end
    
    it 'rejects when call is full' do
      5.times { create(:kazhat_call_participant, call: call, status: 'joined') }
      subscribe call_id: call.id
      expect(subscription).to be_rejected
    end
  end
  
  describe '#answer' do
    it 'marks participant as joined' do
      subscribe call_id: call.id
      participant = call.call_participants.find_by(user: user)
      
      perform :answer
      participant.reload
      expect(participant.status).to eq('joined')
    end
  end
end
```

### Controller Tests

```ruby
# spec/controllers/kazhat/api/v1/calls_controller_spec.rb
RSpec.describe Kazhat::Api::V1::CallsController, type: :controller do
  let(:user) { create(:user) }
  
  before do
    allow(controller).to receive(:current_user).and_return(user)
  end
  
  describe 'GET #index' do
    it 'returns user\'s calls' do
      call = create(:kazhat_call)
      create(:kazhat_call_participant, call: call, user: user)
      
      get :index
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['calls'].length).to eq(1)
    end
  end
  
  describe 'POST #create' do
    let(:other_user) { create(:user) }
    
    it 'creates a new call' do
      expect {
        post :create, params: { user_id: other_user.id, call_type: 'video' }
      }.to change { Kazhat::Call.count }.by(1)
      
      expect(response).to have_http_status(:created)
    end
  end
end
```

---

## Deployment Considerations

### Requirements

**Production Environment:**

- Rails 7.0+
- Ruby 3.0+
- Redis (for ActionCable)
- TURN server (for remote team)

**Browser Requirements:**

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

### Redis Configuration

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: your_app_production
```

### TURN Server Setup

**Option 1: Managed Service (Recommended)**

```ruby
# config/initializers/kazhat.rb
Kazhat.configure do |config|
  config.turn_servers = [
    {
      urls: "turn:global.turn.twilio.com:3478?transport=udp",
      username: ENV["TWILIO_TURN_USERNAME"],
      credential: ENV["TWILIO_TURN_CREDENTIAL"]
    }
  ]
end
```

**Option 2: Self-hosted coturn**

```bash
# On Ubuntu VPS
apt-get install coturn

# Edit /etc/turnserver.conf
listening-port=3478
external-ip=YOUR_SERVER_IP
relay-ip=YOUR_SERVER_IP
fingerprint
lt-cred-mech
user=username:password
realm=yourdomain.com

# Start service
systemctl enable coturn
systemctl start coturn

# Open firewall
ufw allow 3478/tcp
ufw allow 3478/udp
ufw allow 49152:65535/udp
```

### Performance Optimization

**ActionCable Scaling:**

```ruby
# Use Redis adapter with connection pooling
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
  channel_prefix: your_app_production
  pool: 5
```

**Puma Configuration:**

```ruby
# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
```

### Monitoring

**Key Metrics to Track:**

- Active WebSocket connections
- Call success rate
- Call duration average
- Message delivery latency
- TURN server bandwidth usage

**Example with New Relic:**

```ruby
# config/initializers/new_relic.rb
NewRelic::Agent.after_fork(:force_reconnect => true)

# Track custom metrics
NewRelic::Agent.record_metric('Custom/Kazhat/ActiveCalls', Kazhat::Call.active.count)
NewRelic::Agent.record_metric('Custom/Kazhat/OnlineUsers', Kazhat::Connection.count)
```

---

## Troubleshooting Guide

### Common Issues

**1. "Could not access camera/microphone"**

```javascript
// Check browser permissions
navigator.mediaDevices.enumerateDevices()
  .then(devices => {
    console.log('Available devices:', devices)
  })

// In Chrome: chrome://settings/content/camera
// In Firefox: about:preferences#privacy
```

**Solution:** Ensure HTTPS in production, prompt for permissions on user action

---

**2. "Connection failed" (ICE connection failure)**

**Symptoms:** Call rings but no video appears

**Diagnosis:**

```javascript
// Check ICE connection state
pc.oniceconnectionstatechange = () => {
  console.log('ICE state:', pc.iceConnectionState)
}

// Check gathered candidates
pc.onicecandidate = (event) => {
  if (event.candidate) {
    console.log('ICE candidate type:', event.candidate.type)
    // Should see 'host', 'srflx' (STUN), or 'relay' (TURN)
  }
}
```

**Solutions:**

- Verify TURN server credentials
- Check firewall rules (ports 3478, 49152-65535)
- Test with trickle-ice: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/

---

**3. "ActionCable disconnects frequently"**

**Symptoms:** Messages not delivering, call drops

**Diagnosis:**

```ruby
# Check Redis connection
redis = Redis.new(url: ENV['REDIS_URL'])
redis.ping # Should return "PONG"

# Check ActionCable logs
tail -f log/production.log | grep ActionCable
```

**Solutions:**

- Increase Redis timeout: `timeout 0` in redis.conf
- Check load balancer timeout settings
- Verify WebSocket support on proxy/CDN

---

**4. "Call quality is poor"**

**Symptoms:** Choppy video, audio cutting out

**Diagnosis:**

```javascript
// Check network stats
const sender = pc.getSenders().find(s => s.track?.kind === 'video')
const stats = await sender.getStats()
stats.forEach(stat => {
  if (stat.type === 'outbound-rtp') {
    console.log('Packets lost:', stat.packetsLost)
    console.log('Bytes sent:', stat.bytesSent)
  }
})
```

**Solutions:**

- Reduce video quality for more participants
- Use TURN server instead of direct connection
- Check user's bandwidth: https://fast.com

---

**5. "Gem not loading User model"**

**Symptoms:** `NameError: uninitialized constant User`

**Diagnosis:**

```ruby
# In Rails console
Kazhat.configuration.user_class # Should return "User"
Kazhat.configuration.user_class.constantize # Should return User class
```

**Solutions:**

```ruby
# Ensure initializer runs after User is loaded
# config/initializers/kazhat.rb
Rails.application.config.after_initialize do
  Kazhat.configure do |config|
    config.user_class = "User"
  end
end
```

---

## Security Considerations

### WebRTC Security

- Calls are peer-to-peer encrypted by default (DTLS-SRTP)
- TURN credentials should rotate regularly
- Use secure WebSocket (wss://) in production

### ActionCable Security

```ruby
# Ensure user authentication in channels
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include Kazhat::CableAuth
    
    # Automatically handles authentication
  end
end
```

### API Security

- All API endpoints require authentication
- CSRF protection enabled by default
- Rate limiting recommended (use rack-attack)

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('kazhat/api', limit: 100, period: 1.minute) do |req|
  if req.path.start_with?('/kazhat/api')
    req.session[:user_id]
  end
end
```

---

## Future Enhancements (Post v1.0)

### v1.1 - Polish

- [ ] Message search
- [ ] Call recording
- [ ] Screen share with audio
- [ ] Mobile web support
- [ ] Emoji reactions in messages

### v1.2 - Scalability

- [ ] SFU support for larger calls (10-20 people)
- [ ] Multiple TURN servers (failover)
- [ ] Message pagination improvements

### v1.3 - Features

- [ ] File attachments in messages
- [ ] Call waiting
- [ ] Do not disturb mode
- [ ] Custom ringtones

---

## Conclusion

This specification provides a complete blueprint for building the Kazhat Rails engine. The 8-week timeline is realistic for a focused developer or small team.

**Key Success Factors:**

1. Proper namespacing to avoid conflicts
2. Clean data access interface for host apps
3. Focus on desktop-only to avoid mobile complexity
4. 5-person limit makes mesh WebRTC viable
5. TURN server is critical for distributed teams

**Remember:**

- Start with calls (the hard part) before messaging
- Test across different networks early
- Document as you build
- Keep the API simple and predictable

Good luck building Kazhat! 🚀

require "rails/generators"
require "rails/generators/migration"

module Kazhat
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def copy_initializer
        template "initializer.rb", "config/initializers/kazhat.rb"
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
        say "Could not find app/channels/application_cable/connection.rb", :yellow
        say "Please add 'include Kazhat::CableAuth' to your Connection class manually", :yellow
      end

      def check_redis
        if File.exist?("config/cable.yml") && File.read("config/cable.yml").include?("adapter: async")
          say ""
          say "ActionCable is using async adapter (in-memory)", :yellow
          say "For production, you need Redis:", :yellow
          say "  1. Add 'gem \"redis\", \"~> 5.0\"' to Gemfile", :yellow
          say "  2. Update config/cable.yml production adapter to redis", :yellow
          say "  3. Set REDIS_URL in production environment", :yellow
          say ""
        end
      end

      def add_view_helpers
        inject_into_file "app/views/layouts/application.html.erb",
          after: "<head>\n" do
          "    <%= kazhat_meta_tags %>\n"
        end

        # Add kazhat stylesheet
        inject_into_file "app/views/layouts/application.html.erb",
          before: "  </head>" do
          "    <%= stylesheet_link_tag \"kazhat/application\", \"data-turbo-track\": \"reload\" %>\n"
        end

        inject_into_file "app/views/layouts/application.html.erb",
          before: "</body>" do
          "  <%= kazhat_call_container %>\n"
        end
      rescue Errno::ENOENT
        say "Could not find app/views/layouts/application.html.erb", :yellow
        say "Please add view helpers manually", :yellow
      end

      def setup_importmap
        if File.exist?("config/importmap.rb")
          append_to_file "config/importmap.rb" do
            <<~RUBY

              # Kazhat
              pin "kazhat", to: "kazhat/application.js"
              pin "@rails/actioncable", to: "actioncable.esm.js"

              # Kazhat - lib modules
              pin "kazhat/lib/api", to: "kazhat/lib/api.js"
              pin "kazhat/lib/cable", to: "kazhat/lib/cable.js"
              pin "kazhat/lib/call_state", to: "kazhat/lib/call_state.js"
              pin "kazhat/lib/call_popup", to: "kazhat/lib/call_popup.js"
              pin "kazhat/lib/webrtc", to: "kazhat/lib/webrtc.js"

              # Kazhat - controllers
              pin "kazhat/controllers/call_controller", to: "kazhat/controllers/call_controller.js"
              pin "kazhat/controllers/call_controls_controller", to: "kazhat/controllers/call_controls_controller.js"
              pin "kazhat/controllers/call_popup_controller", to: "kazhat/controllers/call_popup_controller.js"
              pin "kazhat/controllers/call_timer_controller", to: "kazhat/controllers/call_timer_controller.js"
              pin "kazhat/controllers/chat_controller", to: "kazhat/controllers/chat_controller.js"
              pin "kazhat/controllers/conversation_list_controller", to: "kazhat/controllers/conversation_list_controller.js"
              pin "kazhat/controllers/incoming_call_controller", to: "kazhat/controllers/incoming_call_controller.js"
              pin "kazhat/controllers/notification_controller", to: "kazhat/controllers/notification_controller.js"
              pin "kazhat/controllers/quick_call_controller", to: "kazhat/controllers/quick_call_controller.js"
              pin "kazhat/controllers/typing_controller", to: "kazhat/controllers/typing_controller.js"
              pin "kazhat/controllers/video_grid_controller", to: "kazhat/controllers/video_grid_controller.js"
            RUBY
          end

          inject_into_file "app/javascript/application.js", after: /import.*controllers.*\n/ do
            "import \"kazhat\"\n"
          end
        else
          say "Importmap not detected. If using jsbundling, add Kazhat to your build.", :yellow
        end
      end

      def check_user_model
        if File.exist?("app/models/user.rb")
          say "User model found", :green
        else
          say "Could not find User model", :yellow
          say "Update config.user_class in config/initializers/kazhat.rb", :yellow
        end
      end

      def show_readme
        say ""
        say "=" * 60
        say "  Kazhat Installation Complete!", :green
        say "=" * 60
        say ""
        say "Next steps:"
        say "  1. Run migrations: rails db:migrate"
        say "  2. Ensure your User model has a display name method:"
        say "       def kazhat_display_name"
        say '         name # or email, first_name + last_name, etc.'
        say "       end"
        say "  3. Configure TURN server for production (recommended)"
        say "  4. Restart your Rails server"
        say "  5. Visit http://localhost:3000/kazhat"
        say ""
        say "=" * 60
      end
    end
  end
end

module Kazhat
  class Engine < ::Rails::Engine
    isolate_namespace Kazhat

    def self.mount_path
      @mount_path ||= begin
        route = Rails.application.routes.routes.find do |r|
          r.app.app == self rescue false
        end
        route&.path&.spec&.to_s || "/kazhat"
      end
    end

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "kazhat.assets" do |app|
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:precompile)
        app.config.assets.precompile += %w[
          kazhat/application.js
          kazhat/application.css
          kazhat/lib/api.js
          kazhat/lib/cable.js
          kazhat/lib/call_state.js
          kazhat/lib/call_popup.js
          kazhat/lib/webrtc.js
          kazhat/controllers/call_controller.js
          kazhat/controllers/call_controls_controller.js
          kazhat/controllers/call_popup_controller.js
          kazhat/controllers/call_timer_controller.js
          kazhat/controllers/chat_controller.js
          kazhat/controllers/conversation_list_controller.js
          kazhat/controllers/incoming_call_controller.js
          kazhat/controllers/notification_controller.js
          kazhat/controllers/quick_call_controller.js
          kazhat/controllers/typing_controller.js
          kazhat/controllers/video_grid_controller.js
        ]
      end
    end

    initializer "kazhat.inject_chatable" do
      ActiveSupport.on_load(:active_record) do
        config = Kazhat.configuration
        if config.user_class.present?
          begin
            user_class = config.user_class.constantize
            user_class.include Kazhat::Chatable unless user_class.include?(Kazhat::Chatable)
          rescue NameError
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

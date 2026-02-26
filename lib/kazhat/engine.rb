module Kazhat
  class Engine < ::Rails::Engine
    isolate_namespace Kazhat

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "kazhat.assets" do |app|
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:precompile)
        app.config.assets.precompile += %w[kazhat/application.js kazhat/application.css]
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

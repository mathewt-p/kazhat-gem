require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"
require "action_view/railtie"
require "active_job/railtie"

Bundler.require(*Rails.groups)
require "kazhat"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.2
    config.eager_load = false
    config.active_support.to_time_preserves_timezone = :zone
    config.root = File.expand_path("..", __dir__)
  end
end

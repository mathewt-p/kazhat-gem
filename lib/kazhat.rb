require "kazhat/version"
require "kazhat/configuration"
require "kazhat/engine"
require "kazhat/cable_auth"
require "kazhat/data_access"

module Kazhat
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

  # Data access methods for host app
  extend DataAccess
end

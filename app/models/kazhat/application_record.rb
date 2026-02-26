module Kazhat
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    def self.kazhat_user_class
      Kazhat.configuration.user_class
    end
  end
end

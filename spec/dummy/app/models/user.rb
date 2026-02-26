class User < ActiveRecord::Base
  include Kazhat::Chatable

  def kazhat_display_name
    name
  end
end

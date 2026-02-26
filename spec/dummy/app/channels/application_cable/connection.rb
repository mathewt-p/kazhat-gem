module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include Kazhat::CableAuth
  end
end

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
        env["warden"]&.user
      end

      def find_user_from_session
        user_id = request.session[:user_id]
        return nil unless user_id
        Kazhat.configuration.user_class_constant.find_by(id: user_id)
      end
    end
  end
end

module Kazhat
  module Api
    module V1
      class BaseController < ActionController::API
        before_action :authenticate_user!

        private

        def current_user
          @current_user ||= begin
            main_app_controller = ActionController::Base.new
            main_app_controller.request = request
            main_app_controller.send(Kazhat.configuration.current_user_method)
          rescue
            request.env["warden"]&.user
          end
        end

        def authenticate_user!
          render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
        end

        def pagination_meta(collection)
          if collection.respond_to?(:current_page)
            {
              current_page: collection.current_page,
              next_page: collection.next_page,
              prev_page: collection.prev_page,
              total_pages: collection.total_pages,
              total_count: collection.total_count
            }
          else
            {
              current_page: 1,
              next_page: nil,
              prev_page: nil,
              total_pages: 1,
              total_count: collection.size
            }
          end
        end
      end
    end
  end
end

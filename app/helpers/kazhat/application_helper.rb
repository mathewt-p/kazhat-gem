module Kazhat
  module ApplicationHelper
    def kazhat_meta_tags
      tags = []

      tags << tag.meta(name: "kazhat-api-url", content: "/kazhat/api/v1")

      tags << tag.meta(name: "kazhat-turn-servers", content: Kazhat.configuration.turn_servers.to_json)

      tags << tag.meta(name: "kazhat-video-quality", content: Kazhat.configuration.video_quality.to_json)

      if respond_to?(Kazhat.configuration.current_user_method) && send(Kazhat.configuration.current_user_method)
        tags << tag.meta(name: "kazhat-user-id", content: send(Kazhat.configuration.current_user_method).id.to_s)
      end

      tags << tag.meta(name: "kazhat-max-participants", content: Kazhat.configuration.max_call_participants.to_s)

      safe_join(tags, "\n")
    end

    def kazhat_call_container
      content_tag :div,
        "",
        id: "kazhat-container",
        data: {
          controller: "kazhat--notification",
          kazhat__notification_user_id_value: (send(Kazhat.configuration.current_user_method)&.id if respond_to?(Kazhat.configuration.current_user_method))
        }
    end

    def kazhat_quick_call_button(user, **options)
      button_text = options.delete(:text) || "Call #{user.kazhat_display_name}"
      call_type = options.delete(:call_type) || "video"

      link_to button_text, "#",
        data: {
          controller: "kazhat--quick-call",
          action: "click->kazhat--quick-call#call",
          kazhat__quick_call_user_id_value: user.id,
          kazhat__quick_call_call_type_value: call_type
        },
        **options
    end
  end
end

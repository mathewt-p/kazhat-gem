import { Application } from "@hotwired/stimulus"
import CallController from "kazhat/controllers/call_controller"
import CallControlsController from "kazhat/controllers/call_controls_controller"
import CallPopupController from "kazhat/controllers/call_popup_controller"
import VideoGridController from "kazhat/controllers/video_grid_controller"
import CallTimerController from "kazhat/controllers/call_timer_controller"
import IncomingCallController from "kazhat/controllers/incoming_call_controller"
import ChatController from "kazhat/controllers/chat_controller"
import ConversationListController from "kazhat/controllers/conversation_list_controller"
import TypingController from "kazhat/controllers/typing_controller"
import NotificationController from "kazhat/controllers/notification_controller"
import QuickCallController from "kazhat/controllers/quick_call_controller"

console.log("[Kazhat] Loading kazhat application.js")

window.Stimulus = window.Stimulus || Application.start()

Stimulus.register("kazhat--call", CallController)
Stimulus.register("kazhat--call-controls", CallControlsController)
Stimulus.register("kazhat--call-popup", CallPopupController)
Stimulus.register("kazhat--video-grid", VideoGridController)
Stimulus.register("kazhat--call-timer", CallTimerController)
Stimulus.register("kazhat--incoming-call", IncomingCallController)
Stimulus.register("kazhat--chat", ChatController)
Stimulus.register("kazhat--conversation-list", ConversationListController)
Stimulus.register("kazhat--typing", TypingController)
Stimulus.register("kazhat--notification", NotificationController)
Stimulus.register("kazhat--quick-call", QuickCallController)

console.log("[Kazhat] All controllers registered")

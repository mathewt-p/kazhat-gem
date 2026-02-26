import { Application } from "@hotwired/stimulus"
import CallController from "./controllers/call_controller"
import CallControlsController from "./controllers/call_controls_controller"
import CallPopupController from "./controllers/call_popup_controller"
import VideoGridController from "./controllers/video_grid_controller"
import CallTimerController from "./controllers/call_timer_controller"
import IncomingCallController from "./controllers/incoming_call_controller"
import ChatController from "./controllers/chat_controller"
import ConversationListController from "./controllers/conversation_list_controller"
import TypingController from "./controllers/typing_controller"
import NotificationController from "./controllers/notification_controller"

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

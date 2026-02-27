import { Controller } from "@hotwired/stimulus"
import { callState } from "kazhat/lib/call_state"

export default class extends Controller {
  static targets = ["popup"]

  connect() {
    this.isDragging = false
    this.unsubscribe = callState.subscribe((state) => this.updateVisibility(state))
  }

  disconnect() {
    if (this.unsubscribe) this.unsubscribe()
  }

  updateVisibility(state) {
    if (!this.hasPopupTarget) return

    const visible = state.callState !== "idle" && state.callState !== "ended"
    this.popupTarget.style.display = visible ? "flex" : "none"

    if (state.isMinimized) {
      this.popupTarget.classList.add("kazhat-minimized")
    } else {
      this.popupTarget.classList.remove("kazhat-minimized")
    }

    if (state.isFullscreen) {
      this.popupTarget.classList.add("kazhat-fullscreen")
    } else {
      this.popupTarget.classList.remove("kazhat-fullscreen")
    }
  }

  toggleFullscreen() {
    const state = callState.get()
    callState.set({ isFullscreen: !state.isFullscreen, isMinimized: false })
  }

  toggleMinimize() {
    const state = callState.get()
    callState.set({ isMinimized: !state.isMinimized, isFullscreen: false })
  }

  startDrag(event) {
    if (callState.get().isFullscreen) return

    this.isDragging = true
    this.dragOffsetX = event.clientX - this.popupTarget.offsetLeft
    this.dragOffsetY = event.clientY - this.popupTarget.offsetTop

    this._moveHandler = (e) => this.onDrag(e)
    this._upHandler = () => this.stopDrag()

    document.addEventListener("mousemove", this._moveHandler)
    document.addEventListener("mouseup", this._upHandler)
  }

  onDrag(event) {
    if (!this.isDragging) return

    const x = event.clientX - this.dragOffsetX
    const y = event.clientY - this.dragOffsetY

    this.popupTarget.style.left = `${x}px`
    this.popupTarget.style.top = `${y}px`
    this.popupTarget.style.right = "auto"
    this.popupTarget.style.bottom = "auto"
  }

  stopDrag() {
    this.isDragging = false
    document.removeEventListener("mousemove", this._moveHandler)
    document.removeEventListener("mouseup", this._upHandler)
  }
}

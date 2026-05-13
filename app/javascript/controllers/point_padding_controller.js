import { Controller } from "@hotwired/stimulus"
import Flash from "./flash_controller"

/**
 * Modal that lets the user pad N inferred points before or after an existing point,
 * spanning a chosen time window with a chosen interpolation mode.
 */
export default class extends Controller {
  static targets = [
    "modal",
    "form",
    "sourcePointInput",
    "countInput",
    "durationValueInput",
    "durationUnitInput",
    "durationSecondsInput",
    "sourceLabel",
  ]

  connect() {
    this._handleOpen = this.open.bind(this)
    document.addEventListener("point-padding:open", this._handleOpen)
  }

  disconnect() {
    document.removeEventListener("point-padding:open", this._handleOpen)
  }

  open(event) {
    const pointId = event.detail?.pointId
    if (!pointId) return

    this.sourcePointInputTarget.value = pointId
    this.sourceLabelTarget.textContent = `Point #${pointId}`
    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  submit() {
    const count = Number.parseInt(this.countInputTarget.value, 10)
    const durationValue = Number.parseInt(
      this.durationValueInputTarget.value,
      10,
    )
    const unit = this.durationUnitInputTarget.value

    if (!Number.isFinite(count) || count < 1 || count > 100) {
      Flash.show("error", "Count must be between 1 and 100")
      return
    }
    if (!Number.isFinite(durationValue) || durationValue < 1) {
      Flash.show("error", "Duration must be at least 1")
      return
    }

    this.durationSecondsInputTarget.value =
      durationValue * this._unitMultiplier(unit)

    this.formTarget.requestSubmit()
    this.close()
  }

  _unitMultiplier(unit) {
    switch (unit) {
      case "seconds":
        return 1
      case "hours":
        return 3600
      case "days":
        return 86400
      default:
        return 60 // minutes
    }
  }
}

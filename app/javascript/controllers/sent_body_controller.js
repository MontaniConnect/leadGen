import { Controller } from "@hotwired/stimulus"

// On submit, copies the CURRENT text of a message box into a hidden field, so "Mark message sent"
// records exactly what was on screen (edits included), even if autosave has not finished.
export default class extends Controller {
  static targets = ["field"]
  static values = { source: String }

  capture() {
    const source = document.getElementById(this.sourceValue)
    if (source) this.fieldTarget.value = source.value
  }
}

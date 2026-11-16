import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Keyboard shortcuts on the lead screen: J/K next/previous lead, C copy first message, S mark sent.
// Ignored while typing in a field, and with any modifier key held.
export default class extends Controller {
  static values = { previousUrl: String, nextUrl: String }

  connect() {
    this.handler = this.handle.bind(this)
    document.addEventListener("keydown", this.handler)
  }

  disconnect() { document.removeEventListener("keydown", this.handler) }

  handle(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    if (event.target.closest("input, textarea, select, [contenteditable]")) return

    switch (event.key.toLowerCase()) {
      case "j": return this.visit(this.nextUrlValue)
      case "k": return this.visit(this.previousUrlValue)
      case "c": return this.click("[data-first-copy]")
      case "s": return this.click("#outreach-next")
    }
  }

  visit(url) { if (url) Turbo.visit(url) }

  click(selector) { this.element.querySelector(selector)?.click() }
}

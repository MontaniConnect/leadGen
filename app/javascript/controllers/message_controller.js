import { Controller } from "@hotwired/stimulus"

// One editable message variant: live word count with an over-limit warning,
// autosave on change, and a Copy button that copies the CURRENT text.
export default class extends Controller {
  static targets = ["field", "count", "warning", "copyButton", "status"]
  static values = { max: { type: Number, default: 50 } }

  connect() { this.count() }
  disconnect() { clearTimeout(this.resetTimer) }

  count() {
    const words = this.fieldTarget.value.trim().split(/\s+/).filter(Boolean).length
    const over = words > this.maxValue
    this.countTarget.textContent = `${words} words`
    this.countTarget.classList.toggle("over", over)
    this.warningTarget.hidden = !over
    this.statusTarget.textContent = ""
  }

  save() {
    if (this.fieldTarget.value.trim() === "") return
    this.statusTarget.textContent = "Saving…"
    this.element.requestSubmit()
  }

  saved(event) {
    this.statusTarget.textContent = event.detail.success ? "Saved" : "Not saved"
  }

  async copy() {
    const text = this.fieldTarget.value
    try {
      await navigator.clipboard.writeText(text)
    } catch (_error) {
      this.fieldTarget.select()
      document.execCommand("copy")
    }
    this.showCopied()
  }

  showCopied() {
    const button = this.copyButtonTarget
    button.textContent = "Copied"
    button.classList.add("copied")
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      button.textContent = "Copy message"
      button.classList.remove("copied")
    }, 2000)
  }
}

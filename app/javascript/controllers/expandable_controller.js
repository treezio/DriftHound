import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]

  toggle() {
    if (!this.hasContentTarget) return

    const isHidden = this.contentTarget.hidden
    this.contentTarget.hidden = !isHidden
    this.element.classList.toggle("expanded", isHidden)
  }
}

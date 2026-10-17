import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.previousFocus = document.activeElement
    this.onKeydown = this.trapFocus.bind(this)
    this.element.addEventListener("keydown", this.onKeydown)
    queueMicrotask(() => {
      if (this.element.isConnected) (this.focusableElements()[0] || this.element).focus()
    })
    // Kunci scroll halaman belakang saat modal terbuka
    document.body.classList.add("overflow-hidden")
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.onKeydown)
    // Kembalikan scroll saat modal ditutup
    document.body.classList.remove("overflow-hidden")
    if (this.previousFocus?.isConnected) this.previousFocus.focus()
  }

  close() {
    // Hapus elemen modal dari layar
    this.element.remove()
    // Direct visits to /machines/new need a destination after closing, too.
    if (window.location.pathname === "/machines/new") window.location.assign("/machines")
  }

  closeBackground(event) {
    // Tutup jika user mengklik area gelap di luar kotak modal
    if (event.target === this.element) {
      this.close()
    }
  }

  closeOnEsc(event) {
    // Tutup jika user menekan tombol ESC
    if (event.key === "Escape") {
      this.close()
    }
  }

  focusableElements() {
    return Array.from(this.element.querySelectorAll(
      'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex="0"]'
    )).filter(element => element.getClientRects().length > 0)
  }

  trapFocus(event) {
    if (event.key !== "Tab") return
    const elements = this.focusableElements()
    const first = elements[0]
    const last = elements[elements.length - 1]
    if (!first) {
      event.preventDefault()
      this.element.focus()
    } else if (event.shiftKey && (document.activeElement === first || document.activeElement === this.element)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }
}

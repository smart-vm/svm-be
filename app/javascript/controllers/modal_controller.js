import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Kunci scroll halaman belakang saat modal terbuka
    document.body.classList.add("overflow-hidden")
  }

  disconnect() {
    // Kembalikan scroll saat modal ditutup
    document.body.classList.remove("overflow-hidden")
  }

  close() {
    // Hapus elemen modal dari layar
    this.element.remove()
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
}
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "topbar", "toggle", "backdrop", "accountMenu", "accountTrigger"]
  static values = { collapsed: Boolean, mobileOpen: Boolean }

  connect() {
    this.breakpoint = window.matchMedia("(max-width: 767px)")
    this.onBreakpointChange = () => {
      this.mobileOpenValue = false
      this.renderState()
    }
    this.breakpoint.addEventListener("change", this.onBreakpointChange)
    try {
      this.collapsedValue = localStorage.getItem("vendora:sidebar:collapsed") === "true"
    } catch { /* Use the expanded default when storage is unavailable. */ }
    this.renderState()
  }

  disconnect() {
    this.breakpoint?.removeEventListener("change", this.onBreakpointChange)
    this.prepareForCache()
  }

  collapsedValueChanged() {
    this.renderState()
  }

  mobileOpenValueChanged() {
    this.renderState()
  }

  toggleSidebar(event) {
    if (!this.hasSidebarTarget) return
    if (this.breakpoint.matches) {
      if (this.mobileOpenValue) return this.closeMobile()
      this.opener = event.currentTarget
      this.accountMenuTarget.removeAttribute("open")
      this.mobileOpenValue = true
      this.renderState()
      requestAnimationFrame(() => {
        if (this.mobileOpenValue) this.sidebarFocusables()[0]?.focus()
      })
    } else {
      this.collapsedValue = !this.collapsedValue
      try {
        localStorage.setItem("vendora:sidebar:collapsed", String(this.collapsedValue))
      } catch { /* Collapsing still works without persistent storage. */ }
    }
  }

  closeMobile() {
    if (!this.mobileOpenValue) return
    this.mobileOpenValue = false
    this.renderState()
    if (this.opener?.isConnected) this.opener.focus()
  }

  renderState() {
    if (!this.breakpoint) return
    const mobile = this.breakpoint.matches
    const drawerOpen = mobile && this.mobileOpenValue
    const expanded = mobile ? drawerOpen : !this.collapsedValue
    const label = mobile ? (drawerOpen ? "Close navigation" : "Open navigation") : (expanded ? "Collapse sidebar" : "Expand sidebar")
    this.toggleTargets.forEach(button => {
      button.setAttribute("aria-expanded", String(expanded))
      button.setAttribute("aria-label", label)
    })
    if (this.hasSidebarTarget) {
      this.sidebarTarget.inert = mobile && !drawerOpen
      if (mobile) {
        this.sidebarTarget.setAttribute("role", "dialog")
        this.sidebarTarget.setAttribute("aria-label", "Navigation")
        this.sidebarTarget.setAttribute("aria-modal", String(drawerOpen))
      } else {
        this.sidebarTarget.removeAttribute("role")
        this.sidebarTarget.removeAttribute("aria-label")
        this.sidebarTarget.removeAttribute("aria-modal")
      }
    }
    if (this.hasBackdropTarget) this.backdropTarget.hidden = !drawerOpen
    if (this.hasTopbarTarget) this.topbarTarget.inert = drawerOpen
    const main = this.element.querySelector("#main-content")
    if (main) main.inert = drawerOpen
    this.element.classList.toggle("erp-drawer-open", drawerOpen)
  }

  closeAccountOutside(event) {
    if (this.hasAccountMenuTarget && !this.accountMenuTarget.contains(event.target)) {
      this.accountMenuTarget.removeAttribute("open")
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      if (this.mobileOpenValue) {
        event.preventDefault()
        this.closeMobile()
      } else if (this.hasAccountMenuTarget && this.accountMenuTarget.open) {
        this.accountMenuTarget.removeAttribute("open")
        this.accountTriggerTarget.focus()
      }
    }
    if (event.key !== "Tab" || !this.mobileOpenValue) return
    const focusable = this.sidebarFocusables()
    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last?.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first?.focus()
    }
  }

  sidebarFocusables() {
    return Array.from(this.sidebarTarget.querySelectorAll('a[href], button:not([disabled])'))
      .filter(element => element.getClientRects().length > 0)
  }

  prepareForCache() {
    this.mobileOpenValue = false
    if (this.hasAccountMenuTarget) this.accountMenuTarget.removeAttribute("open")
    if (this.hasSidebarTarget) this.sidebarTarget.inert = false
    if (this.hasTopbarTarget) this.topbarTarget.inert = false
    const main = this.element.querySelector("#main-content")
    if (main) main.inert = false
    this.element.classList.remove("erp-drawer-open")
  }
}

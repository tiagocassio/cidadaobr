import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenCode", "results", "list"]
  static values = {
    domainKey: String,
    searchUrl: String,
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.debounceTimer = null
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  query() {
    clearTimeout(this.debounceTimer)
    const term = this.inputTarget.value.trim()

    if (term.length < this.minLengthValue) {
      this.clearResults()
      return
    }

    this.debounceTimer = setTimeout(() => this.fetchResults(term), 250)
  }

  select(event) {
    const button = event.currentTarget
    const code = button.dataset.code
    const label = button.dataset.label
    this.inputTarget.value = `${code} — ${label}`
    if (this.hasHiddenCodeTarget) {
      this.hiddenCodeTarget.value = code
    }
    this.clearResults()
  }

  async fetchResults(term) {
    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", term)

    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })

    if (!response.ok) return

    const body = await response.json()
    this.renderResults(body.entries || [])
  }

  renderResults(entries) {
    if (!this.hasListTarget) return

    this.listTarget.innerHTML = ""
    entries.forEach((entry) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "block w-full px-3 py-2 text-left text-sm hover:bg-slate-100"
      item.textContent = `${entry.code} — ${entry.label}`
      item.dataset.action = "reference-domain-autocomplete#select"
      item.dataset.code = entry.code
      item.dataset.label = entry.label
      this.listTarget.appendChild(item)
    })

    if (this.hasResultsTarget) {
      this.resultsTarget.classList.toggle("hidden", entries.length === 0)
    }
  }

  clearResults() {
    if (this.hasListTarget) this.listTarget.innerHTML = ""
    if (this.hasResultsTarget) this.resultsTarget.classList.add("hidden")
  }
}

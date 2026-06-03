import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "rows", "rowTemplate", "row", "removeButton", "destroyField" ]

  static values = {
    clearLabel: String,
    removeLabel: String
  }

  connect() {
    this.updateRemoveButtonLabels()
  }

  addRow(event) {
    event.preventDefault()
    if (!this.hasRowTemplateTarget || !this.hasRowsTarget) return

    const content = this.rowTemplateTarget.innerHTML.replaceAll("NEW_RECORD", Date.now().toString())
    this.rowsTarget.insertAdjacentHTML("beforeend", content)
    this.updateRemoveButtonLabels()
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest("[data-home-visit-campaign-form-target='row']")
    if (!row || !this.hasRowsTarget) return

    if (this.visibleRows().length <= 1) {
      this.clearRow(row)
      return
    }

    this.markRowDestroyed(row)
    this.updateRemoveButtonLabels()
  }

  clearRow(row) {
    row.querySelectorAll("select, input").forEach((field) => {
      if (field.type === "hidden") return
      if (field.tagName === "SELECT") field.selectedIndex = 0
      else if (field.type === "number") field.value = "1"
    })
    const destroyField = row.querySelector("[data-home-visit-campaign-form-target='destroyField']")
    if (destroyField) destroyField.value = "false"
    row.classList.remove("hidden")
  }

  markRowDestroyed(row) {
    const destroyField = row.querySelector("[data-home-visit-campaign-form-target='destroyField']")
    const idField = row.querySelector("input[name*='[id]']")

    if (destroyField && idField?.value) {
      destroyField.value = "1"
      row.classList.add("hidden")
      return
    }

    row.remove()
  }

  visibleRows() {
    return this.rowTargets.filter((row) => !row.classList.contains("hidden"))
  }

  updateRemoveButtonLabels() {
    const singleRow = this.visibleRows().length <= 1

    this.removeButtonTargets.forEach((button) => {
      const row = button.closest("[data-home-visit-campaign-form-target='row']")
      if (!row || row.classList.contains("hidden")) return
      button.textContent = singleRow ? this.clearLabelValue : this.removeLabelValue
    })
  }
}

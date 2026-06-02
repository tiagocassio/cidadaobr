import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "kind", "componentsSection", "rows", "rowTemplate", "row", "addRowButton", "removeButton" ]

  static values = {
    clearLabel: String,
    removeLabel: String
  }

  connect() {
    this.nextIndex = this.initialNextIndex()
    this.toggleComponents()
    this.updateRemoveButtonLabels()
  }

  initialNextIndex() {
    const indices = this.rowTargets.flatMap((row) => {
      const field = row.querySelector("[name*='[components]'][name*='[component_item_id]']")
      if (!field) return []

      const match = field.name.match(/\[components\]\[(\d+)\]/)
      return match ? [ Number(match[1]) ] : []
    })

    return indices.length === 0 ? 0 : Math.max(...indices) + 1
  }

  toggleComponents() {
    if (!this.hasKindTarget || !this.hasComponentsSectionTarget) return

    const composite = this.kindTarget.value === "composite"
    this.componentsSectionTarget.classList.toggle("hidden", !composite)
    this.setComponentFieldsDisabled(!composite)

    if (this.hasAddRowButtonTarget) {
      this.addRowButtonTarget.disabled = !composite
    }
  }

  setComponentFieldsDisabled(disabled) {
    this.rowTargets.forEach((row) => {
      row.querySelectorAll("select, input").forEach((field) => {
        field.disabled = disabled
      })
    })
  }

  addRow(event) {
    event.preventDefault()
    if (!this.hasKindTarget || this.kindTarget.value !== "composite") return
    if (!this.hasRowTemplateTarget || !this.hasRowsTarget) return

    const html = this.rowTemplateTarget.innerHTML.replaceAll("NEW_INDEX", String(this.nextIndex))
    this.nextIndex += 1
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.updateRemoveButtonLabels()
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest("[data-supply-item-form-target='row']")
    if (!row || !this.hasRowsTarget) return

    if (this.rowTargets.length <= 1) {
      row.querySelectorAll("select, input").forEach((field) => {
        if (field.tagName === "SELECT") field.selectedIndex = 0
        else field.value = field.type === "number" ? "1" : ""
      })
      return
    }

    row.remove()
    this.updateRemoveButtonLabels()
  }

  updateRemoveButtonLabels() {
    const singleRow = this.rowTargets.length <= 1

    this.removeButtonTargets.forEach((button) => {
      button.textContent = singleRow ? this.clearLabelValue : this.removeLabelValue
    })
  }
}

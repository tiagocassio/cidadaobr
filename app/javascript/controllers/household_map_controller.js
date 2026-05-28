import { Controller } from "@hotwired/stimulus"
import L from "leaflet"
import "leaflet/dist/leaflet.css"
import markerIcon from "leaflet/dist/images/marker-icon.png"
import markerIcon2x from "leaflet/dist/images/marker-icon-2x.png"
import markerShadow from "leaflet/dist/images/marker-shadow.png"

delete L.Icon.Default.prototype._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow
})

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.map = L.map(this.element).setView([-23.5505, -46.6333], 12)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap"
    }).addTo(this.map)

    this.markerLayer = L.layerGroup().addTo(this.map)
    this.abortController = new AbortController()
    this.loadMarkers = this.loadMarkers.bind(this)
    this.map.on("moveend", this.loadMarkers)
    this.loadMarkers()
  }

  disconnect() {
    this.map?.off("moveend", this.loadMarkers)
    this.abortController?.abort()
    this.map?.remove()
    this.map = null
  }

  loadMarkers() {
    this.abortController?.abort()
    this.abortController = new AbortController()
    this.markerLayer.clearLayers()

    const bounds = this.map.getBounds()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("sw_lat", bounds.getSouth())
    url.searchParams.set("sw_lng", bounds.getWest())
    url.searchParams.set("ne_lat", bounds.getNorth())
    url.searchParams.set("ne_lng", bounds.getEast())

    fetch(url, { headers: { Accept: "application/json" }, signal: this.abortController.signal })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.json()
      })
      .then((markers) => {
        markers.forEach((marker) => {
          const link = document.createElement("a")
          link.href = marker.url
          link.textContent = marker.label || "Domicílio"
          L.marker([marker.lat, marker.lng]).bindPopup(link).addTo(this.markerLayer)
        })
      })
      .catch((error) => {
        if (error.name === "AbortError") return
        console.error("Failed to load household markers", error)
      })
  }
}

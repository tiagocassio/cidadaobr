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

const ROUTE_COLORS = ["#2563eb", "#dc2626", "#16a34a", "#9333ea", "#ea580c", "#0891b2"]

export default class extends Controller {
  static values = { routes: Array, depot: Object, center: Object }

  connect() {
    const center = this.defaultCenter()
    this.map = L.map(this.element).setView(center, 13)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap"
    }).addTo(this.map)

    if (this.hasDepotValue && this.depotValue?.lat != null) {
      L.circleMarker([this.depotValue.lat, this.depotValue.lng], {
        radius: 8,
        color: "#0f172a",
        fillColor: "#0f172a",
        fillOpacity: 0.9
      }).bindPopup(this.depotValue.label || "UBS").addTo(this.map)
    }

    const bounds = []
    this.routesValue.forEach((route, index) => {
      const color = ROUTE_COLORS[index % ROUTE_COLORS.length]
      const latlngs = route.stops.map((stop) => [stop.lat, stop.lng])
      if (latlngs.length === 0) return

      latlngs.forEach((coords, stopIndex) => {
        bounds.push(coords)
        L.marker(coords)
          .bindPopup(`${route.label} · parada ${stopIndex + 1}`)
          .addTo(this.map)
      })

      if (latlngs.length > 1) {
        L.polyline(latlngs, { color, weight: 4, opacity: 0.85 }).addTo(this.map)
      }
    })

    if (bounds.length > 0) {
      this.map.fitBounds(bounds, { padding: [24, 24] })
    }
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }

  defaultCenter() {
    const firstStop = this.routesValue.flatMap((route) => route.stops)[0]
    if (firstStop) return [firstStop.lat, firstStop.lng]
    if (this.hasDepotValue && this.depotValue?.lat != null) return [this.depotValue.lat, this.depotValue.lng]
    if (this.hasCenterValue && this.centerValue?.lat != null) return [this.centerValue.lat, this.centerValue.lng]
    return [-23.5505, -46.6333]
  }
}

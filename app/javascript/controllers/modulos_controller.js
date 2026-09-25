import { Controller } from "@hotwired/stimulus"

// Interruptores de módulos: encender uno marca lo que necesita; apagar uno desmarca a los que lo
// necesitan. Así lo que llega al servidor ya es coherente y nadie se queda a medias.
export default class extends Controller {
  static targets = ["caja"]

  cambiar(event) {
    const caja = event.target
    const lista = (campo) => (caja.dataset[campo] || "").split(" ").filter(Boolean)
    if (caja.checked) {
      lista("necesita").forEach((m) => this.marcar(m, true))
    } else {
      lista("dependientes").forEach((m) => this.marcar(m, false))
    }
  }

  marcar(modulo, valor) {
    const caja = this.cajaTargets.find((c) => c.dataset.modulo === modulo)
    if (caja && caja.checked !== valor) {
      caja.checked = valor
      caja.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}

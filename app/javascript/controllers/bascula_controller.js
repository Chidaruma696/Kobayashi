import { Controller } from "@hotwired/stimulus"
import { Bascula, basculaSimulada } from "kana"

// Báscula Torrey por Web Serial (Kana). Muestra el peso en vivo, y cuando se estabiliza lo pone
// en el campo cantidad y, si auto está activo y el producto es por kilo, manda el formulario.
export default class extends Controller {
  static targets = ["peso", "estado", "cantidad", "form", "producto", "tipo"]
  static values = { auto: Boolean, simulada: Boolean }

  connect() {
    this.bascula = this.simuladaValue ? basculaSimulada() : new Bascula({ clave: "kobayashi:bascula" })
    this.bascula.on("peso", p => { this.pesoTarget.textContent = p.kg.toFixed(3) })
    this.bascula.on("estable", p => this.capturar(p.kg))
    this.bascula.on("retirado", () => { this.pesoTarget.textContent = "0.000" })
    this.bascula.on("estado", e => { this.estadoTarget.textContent = e.mensaje || e.estado })
    this.bascula.on("aviso", a => { this.estadoTarget.textContent = a.mensaje || String(a) })
    if (!this.simuladaValue && Bascula.soportada) this.bascula.reconectar().catch(() => {})
    if (!this.simuladaValue && !Bascula.soportada) this.estadoTarget.textContent = "sin Web Serial (usa Chrome o Edge)"
  }

  disconnect() {
    this.bascula?.desconectar().catch(() => {})
  }

  conectar() {
    this.bascula.conectar().catch(e => { this.estadoTarget.textContent = e.message })
  }

  simular() {
    const kg = Math.round((0.3 + Math.random() * 2.5) * 1000) / 1000
    this.bascula.simulador.colocar(kg)
    setTimeout(() => this.bascula.simulador.retirar(), 2500)
  }

  capturar(kg) {
    if (this.tipoSeleccionado() !== "paquete") return
    if (this.hasProductoTarget && this.productoTarget.selectedOptions[0]?.dataset.unidad !== "kg") return
    this.cantidadTarget.value = kg.toFixed(3)
    if (this.autoValue) this.formTarget.requestSubmit()
  }

  enviado(event) {
    if (event.detail.success) this.cantidadTarget.value = ""
  }

  tipoSeleccionado() {
    return this.tipoTargets.find(t => t.checked)?.value || "paquete"
  }
}

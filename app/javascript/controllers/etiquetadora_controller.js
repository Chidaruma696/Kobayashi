import { Controller } from "@hotwired/stimulus"
import { Bascula, basculaSimulada } from "kana"

// La etiquetadora: se elige un producto y la pantalla se acomoda a su unidad. Por kilo hay una
// sola lista de pesadas que se llena desde la báscula, a mano o con "N × peso"; por pieza solo
// se dice cuántas piezas. Dos preferencias quietas (cerrar en caja, imprimir al vuelo) y una
// acción: Registrar e imprimir. Los códigos los asigna el servidor; aquí nunca se inventan.
export default class extends Controller {
  static targets = [
    "aviso", "estado", "peso", "btnBascula", "btnCapturar",
    "buscador", "resultados", "ficha",
    "panelKg", "manual", "qn", "qpeso", "qtotal", "qhint",
    "panelPieza", "piezas", "piezaNota", "btnCopias",
    "panelLista", "resumen", "enCaja", "alVuelo", "alVueloLabel", "lista", "pin", "justificacion",
    "btnRegistrar", "btnReimprimir", "resultado",
    "cfgAncho", "cfgAlto", "cfgLeyenda", "cfgBarras", "cfgLetra"
  ]
  static values = { loteUrl: String, productosUrl: String, imprimirUrl: String, pedidoLineaId: String, produccionId: String, producto: Object, simulada: Boolean }

  CFG_CLAVE = "kobayashi:etiqueta_cfg"
  CFG_DEFAULT = { ancho: 55, alto: 45, leyenda: "", barras: 36, letra: 14 }
  PREFS_CLAVE = "kobayashi:etiquetar_prefs"

  connect() {
    this.producto = null
    this.pesadas = []          // [{ cantidad, origen, id?, codigo? }]
    this.caja = null           // caja registrada del lote actual
    this.registrado = false
    this.colaVuelo = Promise.resolve()
    this.ventana = null
    this.cargarCfg()
    this.cargarPrefs()
    this.iniciarBascula()
    if (this.productoValue?.id) this.elegir(this.productoValue)
    else this.buscadorTarget.focus()
  }

  disconnect() { this.bascula?.desconectar().catch(() => {}) }

  // ---------------------------------------------------------------- utilidades

  avisar(texto) { this.avisoTarget.textContent = texto || "" }
  esc(s) { return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])) }
  fmt(n) { return Number(n).toFixed(this.porPieza ? 0 : 3) }
  get porPieza() { return this.producto?.unidad === "pieza" }
  get unidad() { return this.porPieza ? "pz" : "kg" }

  // ---------------------------------------------------------------- producto

  async buscar() {
    const q = this.buscadorTarget.value.trim()
    const r = await fetch(`${this.productosUrlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
    if (!r.ok || this.buscadorTarget.value.trim() !== q) return
    this.candidatos = await r.json()
    this.resultadosTarget.innerHTML = this.candidatos.length
      ? this.candidatos.map((p, i) => `<div class="cursor-pointer border-b border-slate-100 px-3 py-2 text-sm hover:bg-slate-100 ${i === 0 ? "bg-slate-100" : ""}" data-idx="${i}" data-action="mousedown->etiquetadora#elegirResultado"><span class="font-semibold">${this.esc(p.nombre)}</span> <span class="text-slate-500">${this.esc(p.clave)} · PLU ${p.plu} · ${p.unidad}</span></div>`).join("")
      : `<div class="px-3 py-2 text-sm text-slate-500">Sin resultados</div>`
    this.resultadosTarget.classList.remove("hidden")
    if (this.candidatos.length === 1 && /^\d{8,}$/.test(q)) this.elegir(this.candidatos[0])
  }

  teclaBuscador(e) {
    const items = [ ...this.resultadosTarget.querySelectorAll("[data-idx]") ]
    let i = items.findIndex(el => el.classList.contains("bg-slate-100"))
    if (e.key === "Escape") { this.resultadosTarget.classList.add("hidden"); return }
    if (e.key === "Enter") { e.preventDefault(); if (i >= 0) this.elegir(this.candidatos[i]); return }
    if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return
    e.preventDefault()
    if (!items.length) return
    i = e.key === "ArrowDown" ? Math.min(i + 1, items.length - 1) : Math.max(i - 1, 0)
    items.forEach(el => el.classList.remove("bg-slate-100")); items[i].classList.add("bg-slate-100"); items[i].scrollIntoView({ block: "nearest" })
  }

  elegirResultado(e) { this.elegir(this.candidatos[Number(e.currentTarget.dataset.idx)]) }
  ocultarResultados() { setTimeout(() => this.resultadosTarget.classList.add("hidden"), 150) }

  elegir(p) {
    this.producto = p
    this.buscadorTarget.value = p.nombre
    this.resultadosTarget.classList.add("hidden")
    this.limpiar()
    const pf = Number(p.peso_fijo || 0)
    const partes = [ `<strong>${this.esc(p.nombre)}</strong>`, this.esc(p.clave), `PLU ${p.plu}`, p.unidad ]
    if (pf > 0) partes.push(`peso fijo ${pf.toFixed(3)} kg`)
    partes.push(p.codigos.length ? `código de proveedor <code>${this.esc(p.codigos.join(", "))}</code>` : "sin código de proveedor")
    this.fichaTarget.innerHTML = partes.join(" · ")
    this.fichaTarget.classList.remove("hidden")
    this.panelKgTarget.classList.toggle("hidden", this.porPieza)
    this.panelPiezaTarget.classList.toggle("hidden", !this.porPieza)
    this.alVueloLabelTarget.classList.toggle("hidden", this.porPieza)
    this.panelListaTarget.classList.remove("hidden")
    if (this.porPieza) {
      this.piezaNotaTarget.textContent = p.codigos.length ? "Con código de proveedor: la caja se recibe y se vende escaneando ese código." : "Sin código de proveedor: cada pieza necesita su etiqueta (apaga «Cerrar en caja»)."
      this.btnCopiasTarget.classList.toggle("hidden", !p.codigos.length)
      this.piezasTarget.focus()
    } else {
      if (pf > 0) this.qpesoTarget.value = pf.toFixed(3)
      this.manualTarget.focus()
    }
    this.pintarLista()
  }

  // ---------------------------------------------------------------- pesadas

  agregarManual() {
    const kg = Number(this.manualTarget.value) || 0
    if (!(kg > 0)) { this.avisar("Escribe un peso mayor que cero"); return }
    this.manualTarget.value = ""
    this.agregar(kg, "manual")
  }

  capturar() {
    const kg = this.bascula.peso
    if (!(kg > 0.02)) { this.avisar("La báscula marca cero"); return }
    this.agregar(kg, "báscula")
  }

  recalcularQuick() {
    const n = parseInt(this.qnTarget.value) || 0
    const total = Number(this.qtotalTarget.value) || 0
    if (total > 0 && n > 0) { this.qpesoTarget.value = (total / n).toFixed(3); this.qhintTarget.textContent = `= ${(total / n).toFixed(3)} kg c/u` }
    else this.qhintTarget.textContent = ""
  }

  agregarVarias() {
    const n = parseInt(this.qnTarget.value) || 0
    const kg = Number(this.qpesoTarget.value) || 0
    if (n < 1 || !(kg > 0)) { this.avisar("Indica cuántas y de cuánto"); return }
    for (let i = 0; i < n; i++) this.agregar(kg, "manual", true)
    this.qtotalTarget.value = ""; this.qhintTarget.textContent = ""
    this.pintarLista()
  }

  agregar(kg, origen, silencioso = false) {
    if (!this.producto) { this.avisar("Elige el producto primero"); return }
    if (this.registrado) { this.pesadas = []; this.caja = null; this.registrado = false; this.resultadoTarget.textContent = "" }
    const pesada = { cantidad: Number(kg.toFixed(3)), origen }
    this.pesadas.push(pesada)
    this.avisar("")
    if (!silencioso) this.pintarLista()
    if (this.alVueloTarget.checked && !this.porPieza) this.registrarAlVuelo(pesada)
  }

  quitar(e) {
    const p = this.pesadas[Number(e.currentTarget.dataset.idx)]
    if (p.id) { this.avisar(`${p.codigo} ya está registrada; si sobra, dala de baja en Vivas`); return }
    this.pesadas.splice(Number(e.currentTarget.dataset.idx), 1)
    this.pintarLista()
  }

  limpiar() {
    this.pesadas = []; this.caja = null; this.registrado = false
    this.resultadoTarget.textContent = ""
    this.avisar("")
    this.pintarLista()
  }

  pintarLista() {
    if (!this.producto) return
    const n = this.porPieza ? (parseInt(this.piezasTarget.value) || 0) : this.pesadas.length
    const total = this.porPieza ? n : this.pesadas.reduce((a, p) => a + p.cantidad, 0)
    const caja = this.enCajaTarget.checked
    this.resumenTarget.textContent = this.porPieza
      ? (caja ? `Una caja de ${n} piezas` : `${n} etiquetas de 1 pieza`)
      : (n ? `${n} pesadas · ${total.toFixed(3)} kg${caja ? " · en una caja" : " · sueltas"}` : "Sin pesadas")
    const filas = this.porPieza
      ? (caja ? [] : Array.from({ length: n }, (_, i) => ({ i, origen: "pieza", cantidad: 1 })))
      : this.pesadas.map((p, i) => ({ i, ...p }))
    this.listaTarget.innerHTML = filas.map(f => `<tr class="border-t border-slate-100">
        <td class="px-4 py-1 text-slate-400">${f.i + 1}</td>
        <td class="px-2 py-1 text-slate-500">${f.origen}</td>
        <td class="px-2 py-1 text-right font-mono">${this.fmt(f.cantidad)} ${this.unidad}</td>
        <td class="px-2 py-1 font-mono text-xs ${f.codigo ? "text-emerald-700" : "text-slate-400"}">${f.codigo || "al registrar"}</td>
        <td class="px-2 py-1 text-right">${this.porPieza ? "" : `<button type="button" class="text-slate-400 hover:text-red-700" data-idx="${f.i}" data-action="etiquetadora#quitar">✕</button>`}</td>
      </tr>`).join("")
    if (this.caja) this.listaTarget.insertAdjacentHTML("afterbegin", `<tr class="border-t border-amber-200 bg-amber-50 font-semibold"><td class="px-4 py-1">📦</td><td class="px-2 py-1">caja</td><td class="px-2 py-1 text-right font-mono">${this.fmt(this.caja.cantidad)} ${this.unidad}</td><td class="px-2 py-1 font-mono text-xs text-emerald-700">${this.caja.codigo}</td><td></td></tr>`)
    this.btnRegistrarTarget.classList.toggle("hidden", this.registrado)
    this.btnReimprimirTarget.classList.toggle("hidden", !this.registrado)
  }

  // ---------------------------------------------------------------- registrar e imprimir

  async registrar() {
    if (!this.producto) return
    const caja = this.enCajaTarget.checked
    let cuerpo
    if (this.porPieza) {
      const n = parseInt(this.piezasTarget.value) || 0
      if (n < 1) { this.avisar("Indica cuántas piezas"); return }
      cuerpo = caja ? { caja_fija: n } : { pesadas: Array.from({ length: n }, () => ({ cantidad: 1 })) }
    } else {
      if (!this.pesadas.length) { this.avisar("No hay pesadas"); return }
      cuerpo = { pesadas: this.pesadas.map(p => p.id ? { id: p.id } : { cantidad: p.cantidad }), caja: caja ? "1" : "" }
    }
    this.btnRegistrarTarget.disabled = true
    try {
      await this.colaVuelo
      const datos = await this.enviar(cuerpo)
      if (!datos) return
      if (this.porPieza) this.pesadas = datos.etiquetas.map(e => ({ ...e, origen: "pieza" }))
      else datos.etiquetas.forEach((e, i) => Object.assign(this.pesadas[i], e))
      this.caja = datos.caja
      this.registrado = true
      this.actualizarLleva(datos.lleva)
      this.resultadoTarget.textContent = this.caja ? `Caja ${this.caja.codigo} registrada` : `${datos.etiquetas.length} etiquetas registradas`
      this.pintarLista()
      this.reimprimir()
    } finally {
      this.btnRegistrarTarget.disabled = false
    }
  }

  // Al vuelo: cada pesada se registra en cuanto entra y se imprime con su código; la caja se arma al final.
  registrarAlVuelo(pesada) {
    this.colaVuelo = this.colaVuelo.then(async () => {
      const datos = await this.enviar({ pesadas: [ { cantidad: pesada.cantidad } ] })
      if (!datos) return
      Object.assign(pesada, datos.etiquetas[0])
      this.actualizarLleva(datos.lleva)
      this.pintarLista()
      this.imprimir({ ids: pesada.id })
    })
  }

  reimprimir() {
    const ids = [ this.caja?.id, ...this.pesadas.map(p => p.id) ].filter(Boolean)
    if (!ids.length) { this.avisar("Nada registrado todavía"); return }
    this.imprimir({ ids: ids.join(",") })
  }

  copiasProveedor() {
    const n = parseInt(this.piezasTarget.value) || 0
    if (n < 1 || !this.producto?.codigos.length) return
    const pf = Number(this.producto.peso_fijo || 0)
    this.imprimir({ codigo: this.producto.codigos[0], n, nombre: this.producto.nombre, cantidad: pf > 0 ? `${pf.toFixed(3)} kg` : "1 pz" })
  }

  imprimir(extra) {
    const c = this.cfg()
    const url = `${this.imprimirUrlValue}?${new URLSearchParams({ ...extra, ancho: c.ancho, alto: c.alto, leyenda: c.leyenda, bc: c.barras, fn: c.letra, imprimir: 1 })}`
    if (!this.ventana || this.ventana.closed) this.ventana = window.open(url, "kobayashi_etiquetas", "width=480,height=420,popup")
    else this.ventana.location.href = url
    if (!this.ventana) this.avisar("Permite las ventanas emergentes para imprimir")
  }

  async enviar(cuerpo) {
    const r = await fetch(this.loteUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: JSON.stringify({
        producto_id: this.producto.id, pedido_linea_id: this.pedidoLineaIdValue, produccion_id: this.produccionIdValue,
        pin: this.hasPinTarget ? this.pinTarget.value : "", justificacion: this.hasJustificacionTarget ? this.justificacionTarget.value : "",
        ...cuerpo
      })
    })
    const datos = await r.json()
    if (!r.ok) { this.avisar(datos.error || "No se pudo registrar"); return null }
    this.avisar("")
    return datos
  }

  actualizarLleva(lleva) {
    const span = document.getElementById("lleva")
    if (span && lleva != null) span.textContent = lleva
  }

  // ---------------------------------------------------------------- báscula (Kana)

  iniciarBascula() {
    this.bascula = this.simuladaValue ? basculaSimulada() : new Bascula({ clave: "kobayashi:bascula" })
    this.bascula.on("peso", p => { this.pesoTarget.textContent = p.kg.toFixed(3) })
    this.bascula.on("estable", p => {
      this.estadoTarget.textContent = `estable ${p.kg.toFixed(3)} kg`
      if (this.producto && !this.porPieza) this.agregar(p.kg, "báscula")
    })
    this.bascula.on("retirado", () => { this.pesoTarget.textContent = "0.000"; this.estadoTarget.textContent = "coloca paquete" })
    this.bascula.on("estado", e => {
      const on = e.estado === "conectada"
      this.estadoTarget.textContent = e.mensaje || e.estado
      this.btnBasculaTarget.textContent = on ? "desconectar" : "conectar"
      this.btnCapturarTarget.disabled = !on
    })
    this.bascula.on("aviso", a => { this.estadoTarget.textContent = a.mensaje || String(a) })
    // ?depurar=1 enseña la trama cruda bajo el peso, para ver qué manda la báscula cuando algo se atora.
    if (new URLSearchParams(location.search).has("depurar")) {
      this.bascula.on("trama", t => { this.estadoTarget.textContent = JSON.stringify(t.texto); console.debug("[báscula]", t.texto) })
    }
    if (!this.simuladaValue && Bascula.soportada) this.bascula.reconectar().catch(() => {})
    if (!this.simuladaValue && !Bascula.soportada) this.estadoTarget.textContent = "sin Web Serial (usa Chrome o Edge)"
  }

  async alternarBascula() {
    if (this.bascula.conectada) await this.bascula.desconectar()
    else await this.bascula.conectar()
  }

  simular() {
    const kg = Math.round((0.3 + Math.random() * 2.5) * 1000) / 1000
    this.bascula.simulador.colocar(kg)
    setTimeout(() => this.bascula.simulador.retirar(), 2500)
  }

  // ---------------------------------------------------------------- preferencias

  cargarPrefs() {
    let p = { caja: true, alVuelo: false }
    try { p = { ...p, ...JSON.parse(localStorage.getItem(this.PREFS_CLAVE) || "{}") } } catch { /* sin storage */ }
    this.enCajaTarget.checked = p.caja
    this.alVueloTarget.checked = p.alVuelo
  }

  guardarPrefs() {
    try { localStorage.setItem(this.PREFS_CLAVE, JSON.stringify({ caja: this.enCajaTarget.checked, alVuelo: this.alVueloTarget.checked })) } catch { /* sin storage */ }
  }

  cfg() {
    return {
      ancho: parseInt(this.cfgAnchoTarget.value) || this.CFG_DEFAULT.ancho,
      alto: parseInt(this.cfgAltoTarget.value) || this.CFG_DEFAULT.alto,
      leyenda: this.cfgLeyendaTarget.value || "",
      barras: parseInt(this.cfgBarrasTarget.value) || this.CFG_DEFAULT.barras,
      letra: parseInt(this.cfgLetraTarget.value) || this.CFG_DEFAULT.letra
    }
  }

  cargarCfg() {
    let s = {}
    try { s = JSON.parse(localStorage.getItem(this.CFG_CLAVE) || "{}") } catch { s = {} }
    const c = { ...this.CFG_DEFAULT, ...s }
    this.cfgAnchoTarget.value = c.ancho; this.cfgAltoTarget.value = c.alto; this.cfgLeyendaTarget.value = c.leyenda
    this.cfgBarrasTarget.value = c.barras; this.cfgLetraTarget.value = c.letra
  }

  guardarCfg() { try { localStorage.setItem(this.CFG_CLAVE, JSON.stringify(this.cfg())) } catch { /* sin storage */ } }
  restablecerCfg() { try { localStorage.removeItem(this.CFG_CLAVE) } catch { /* sin storage */ } this.cargarCfg() }
}

import { Controller } from "@hotwired/stimulus"
import { Bascula, basculaSimulada } from "kana"

// La etiquetadora: se elige un producto y la pantalla se acomoda a su unidad. Por kilo hay una
// sola lista de pesadas que se llena desde la báscula, a mano o con "N × peso"; por pieza solo
// se dice cuántas piezas. Dos preferencias quietas (cerrar en caja, imprimir al vuelo) y una
// acción: Registrar e imprimir. Los códigos los asigna el servidor; aquí nunca se inventan.
// Contra un pedido, lo registrado entra solo a la salida de ese destino; si etiqueté mal, el
// bote de cada renglón lo da de baja con motivo y lo saca de la salida.
export default class extends Controller {
  static targets = [
    "aviso", "estado", "peso", "btnBascula", "btnCapturar",
    "buscador", "resultados", "ficha", "fabrica", "codigoNuevo", "pesoFijoInput", "codigosLista",
    "panelKg", "manual", "qn", "qpeso", "qtotal", "qhint",
    "panelPieza", "piezas", "piezaNota", "btnCopias",
    "panelLista", "resumen", "enCaja", "alVuelo", "alVueloLabel", "lista", "justificacion",
    "btnRegistrar", "btnReimprimir", "resultado", "salida",
    "cfgAncho", "cfgAlto", "cfgLeyenda", "cfgBarras", "cfgLetra"
  ]
  static values = { loteUrl: String, productosUrl: String, imprimirUrl: String, etiquetasUrl: String, adminProductosUrl: String,
                    pedidoLineaId: String, produccionId: String, sustituto: Boolean, producto: Object, simulada: Boolean, cfgDefault: Object }

  CFG_CLAVE = "kobayashi:etiqueta_cfg"
  get CFG_DEFAULT() { return { ancho: 55, alto: 45, leyenda: "", barras: 36, letra: 14, ...(this.cfgDefaultValue || {}) } }
  PREFS_CLAVE = "kobayashi:etiquetar_prefs"

  connect() {
    this.producto = null
    this.pesadas = []          // [{ cantidad, origen, id?, codigo?, baja? }]
    this.caja = null           // caja registrada del lote actual { id, codigo, cantidad, baja? }
    this.salida = null         // salida donde va cayendo lo registrado { id, folio, url, paquetes }
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
  get unidad() { const u = this.producto?.unidad || "kg"; return T.unidades[u] || u }
  get porKilo() { return this.producto?.unidad === "kg" }
  get pesoFijo() { return Number(this.producto?.peso_fijo || 0) }
  get csrf() { return document.querySelector("meta[name=csrf-token]")?.content }

  async pedir(url, metodo, cuerpo) {
    const r = await fetch(url, {
      method: metodo,
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": this.csrf },
      body: cuerpo ? JSON.stringify(cuerpo) : undefined
    })
    const datos = r.status === 204 ? {} : await r.json().catch(() => ({}))
    if (!r.ok) { this.avisar(datos.error || T.no_se_pudo); return null }
    this.avisar("")
    return datos
  }

  // ---------------------------------------------------------------- producto

  async buscar() {
    const q = this.buscadorTarget.value.trim()
    const r = await fetch(`${this.productosUrlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
    if (!r.ok || this.buscadorTarget.value.trim() !== q) return
    this.candidatos = await r.json()
    this.resultadosTarget.innerHTML = this.candidatos.length
      ? this.candidatos.map((p, i) => `<div class="cursor-pointer border-b border-stone-100 px-3 py-2 text-sm hover:bg-stone-100 ${i === 0 ? "bg-stone-100" : ""}" data-idx="${i}" data-action="mousedown->etiquetadora#elegirResultado"><span class="font-semibold">${this.esc(p.nombre)}</span> <span class="text-stone-500">${this.esc(p.clave)} · PLU ${p.plu} · ${p.unidad}</span></div>`).join("")
      : `<div class="px-3 py-2 text-sm text-stone-500">${T.sin_resultados}</div>`
    this.resultadosTarget.classList.remove("hidden")
    if (this.candidatos.length === 1 && /^\d{8,}$/.test(q)) this.elegir(this.candidatos[0])
  }

  teclaBuscador(e) {
    const items = [ ...this.resultadosTarget.querySelectorAll("[data-idx]") ]
    let i = items.findIndex(el => el.classList.contains("bg-stone-100"))
    if (e.key === "Escape") { this.resultadosTarget.classList.add("hidden"); return }
    if (e.key === "Enter") { e.preventDefault(); if (i >= 0) this.elegir(this.candidatos[i]); return }
    if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return
    e.preventDefault()
    if (!items.length) return
    i = e.key === "ArrowDown" ? Math.min(i + 1, items.length - 1) : Math.max(i - 1, 0)
    items.forEach(el => el.classList.remove("bg-stone-100")); items[i].classList.add("bg-stone-100"); items[i].scrollIntoView({ block: "nearest" })
  }

  elegirResultado(e) { this.elegir(this.candidatos[Number(e.currentTarget.dataset.idx)]) }
  ocultarResultados() { setTimeout(() => this.resultadosTarget.classList.add("hidden"), 150) }

  elegir(p) {
    this.producto = p
    this.buscadorTarget.value = p.nombre
    this.resultadosTarget.classList.add("hidden")
    this.reiniciar()
    this.pintarFicha()
    this.acomodarPanel()
  }

  // Ficha con chips (clave, PLU, unidad, peso fijo, código de proveedor) y el plegable de fábrica.
  pintarFicha() {
    const p = this.producto
    const chip = (texto, color = "bg-marca-50 text-marca-800") => `<span class="rounded px-2 py-0.5 text-xs font-semibold ${color}">${texto}</span>`
    const chips = [ `<span class="text-base font-bold">${this.esc(p.nombre)}</span>`, chip(`ID ${this.esc(p.clave)}`), chip(`PLU ${p.plu}`), chip(`${T.etq.unidad} ${p.unidad}`) ]
    if (this.pesoFijo > 0) chips.push(chip(`${T.etq.peso_fijo} ${this.pesoFijo.toFixed(3)} kg`, "bg-blue-50 text-blue-700"))
    if (p.codigos.length) chips.push(chip(`${T.etq.codigo_proveedor} <code>${this.esc(p.codigos.join(", "))}</code>`, "bg-amber-50 text-amber-700"))
    this.fichaTarget.innerHTML = chips.join("")
    this.fichaTarget.classList.remove("hidden"); this.fichaTarget.classList.add("flex")
    if (!this.hasFabricaTarget) return
    this.fabricaTarget.classList.remove("hidden")
    this.codigoNuevoTarget.value = ""
    this.pesoFijoInputTarget.value = this.pesoFijo > 0 ? this.pesoFijo.toFixed(3) : ""
    const detalle = p.codigos_detalle || p.codigos.map(c => ({ id: null, codigo: c }))
    this.codigosListaTarget.innerHTML = detalle.length
      ? detalle.map(c => `<li class="flex items-center gap-2"><code class="rounded bg-stone-100 px-2 py-0.5">${this.esc(c.codigo)}</code>${c.id ? `<button type="button" class="btn btn-ghost-danger btn-xs" data-id="${c.id}" data-action="etiquetadora#quitarCodigo">${T.etq.quitar}</button>` : ""}</li>`).join("")
      : `<li class="text-xs text-stone-500">${T.etq.sin_codigo_fijo}</li>`
  }

  // Vincula el código de fábrica y/o el peso por pieza (va a Admin → Productos por JSON).
  async vincular() {
    if (!this.producto) return
    const codigo = this.codigoNuevoTarget.value.trim()
    const peso = this.pesoFijoInputTarget.value.trim()
    const pesoActual = this.pesoFijo > 0 ? this.pesoFijo.toFixed(3) : ""
    if (!codigo && peso === pesoActual) { this.avisar(T.etq.escribe_codigo_o_peso); return }
    const base = `${this.adminProductosUrlValue}/${this.producto.id}`
    if (codigo) {
      const d = await this.pedir(`${base}/codigos`, "POST", { codigo })
      if (!d) return
      this.producto.codigos.push(d.codigo)
      this.producto.codigos_detalle = [ ...(this.producto.codigos_detalle || []), d ]
    }
    if (peso !== pesoActual) {
      const d = await this.pedir(base, "PATCH", { producto: { peso_fijo: peso } })
      if (!d) return
      this.producto.peso_fijo = d.peso_fijo
    }
    this.resultadoTarget.textContent = T.etq.vinculado
    this.pintarFicha()
    this.acomodarPanel()
  }

  async quitarCodigo(e) {
    const id = Number(e.currentTarget.dataset.id)
    if (!confirm(T.etq.confirmar_quitar_codigo)) return
    const d = await this.pedir(`${this.adminProductosUrlValue}/${this.producto.id}/codigos/${id}`, "DELETE")
    if (!d) return
    this.producto.codigos_detalle = this.producto.codigos_detalle.filter(c => c.id !== id)
    this.producto.codigos = this.producto.codigos_detalle.map(c => c.codigo)
    this.pintarFicha()
    this.acomodarPanel()
  }

  // La pantalla se acomoda a la unidad del producto: kilo = lista de pesadas; pieza = cuántas.
  acomodarPanel() {
    const p = this.producto
    this.panelKgTarget.classList.toggle("hidden", this.porPieza)
    this.panelPiezaTarget.classList.toggle("hidden", !this.porPieza)
    this.alVueloLabelTarget.classList.toggle("hidden", this.porPieza)
    this.panelListaTarget.classList.remove("hidden")
    if (this.porPieza) {
      this.piezaNotaTarget.textContent = p.codigos.length ? T.etq.con_codigo_proveedor : T.etq.sin_codigo_proveedor
      this.btnCopiasTarget.classList.toggle("hidden", !p.codigos.length)
      this.piezasTarget.focus()
    } else {
      if (this.pesoFijo > 0) this.qpesoTarget.value = this.pesoFijo.toFixed(3)
      this.manualTarget.focus()
    }
    this.pintarLista()
  }

  // ---------------------------------------------------------------- pesadas

  agregarManual() {
    const kg = Number(this.manualTarget.value) || 0
    if (!(kg > 0)) { this.avisar(T.etq.peso_mayor_cero); return }
    this.manualTarget.value = ""
    this.agregar(kg, "manual")
  }

  capturar() {
    const kg = this.bascula.peso
    if (!(kg > 0.02)) { this.avisar(T.etq.bascula_cero); return }
    this.agregar(kg, "bascula")
  }

  recalcularQuick() {
    const n = parseInt(this.qnTarget.value) || 0
    const total = Number(this.qtotalTarget.value) || 0
    if (total > 0 && n > 0) { this.qpesoTarget.value = (total / n).toFixed(3); this.qhintTarget.textContent = `= ${(total / n).toFixed(3)} ${T.etq.kg_cu}` }
    else this.qhintTarget.textContent = ""
  }

  agregarVarias() {
    const n = parseInt(this.qnTarget.value) || 0
    const kg = Number(this.qpesoTarget.value) || 0
    if (n < 1 || !(kg > 0)) { this.avisar(T.etq.cuantas_y_cuanto); return }
    for (let i = 0; i < n; i++) this.agregar(kg, "manual", true)
    this.qtotalTarget.value = ""; this.qhintTarget.textContent = ""
    this.pintarLista()
  }

  agregar(kg, origen, silencioso = false) {
    if (!this.producto) { this.avisar(T.etq.elige_producto); return }
    if (this.porPieza) return
    if (this.registrado) { this.pesadas = []; this.caja = null; this.registrado = false; this.resultadoTarget.textContent = "" }
    const pesada = { cantidad: Number(kg.toFixed(3)), origen }
    this.pesadas.push(pesada)
    this.avisar("")
    if (!silencioso) this.pintarLista()
    if (this.alVueloTarget.checked) this.registrarAlVuelo(pesada)
  }

  quitar(e) {
    const p = this.pesadas[Number(e.currentTarget.dataset.idx)]
    if (p.id) return
    this.pesadas.splice(Number(e.currentTarget.dataset.idx), 1)
    this.pintarLista()
  }

  limpiar() {
    const vivas = this.pesadas.filter(p => p.id && !p.baja).length
    if (vivas && !this.registrado && !confirm(`${vivas} ${T.etq.confirmar_limpiar}`)) return
    this.reiniciar()
  }

  reiniciar() {
    this.pesadas = []; this.caja = null; this.registrado = false
    this.resultadoTarget.textContent = ""
    this.avisar("")
    this.pintarLista()
  }

  pintarLista() {
    if (!this.producto) return
    const n = this.porPieza ? (parseInt(this.piezasTarget.value) || 0) : this.pesadas.length
    const total = this.porPieza ? n : this.pesadas.reduce((a, p) => a + (p.baja ? 0 : p.cantidad), 0)
    const enCaja = this.enCajaTarget.checked
    this.resumenTarget.textContent = this.porPieza
      ? (enCaja ? `${T.etq.una_caja_de} ${n} ${T.etq.piezas}` : `${n} ${T.etq.etiquetas_de_1_pieza}`)
      : (n ? `${n} ${T.etq.pesadas} · ${total.toFixed(3)} kg${enCaja ? ` · ${T.etq.en_una_caja}` : ` · ${T.etq.sueltas}`}` : T.etq.sin_pesadas)
    let filas
    if (this.porPieza) {
      filas = this.registrado
        ? this.pesadas.map((p, i) => ({ i, ...p, origen: "pieza" }))
        : (enCaja ? [] : Array.from({ length: n }, (_, i) => ({ i, origen: "pieza", cantidad: 1 })))
    } else {
      filas = this.pesadas.map((p, i) => ({ i, ...p }))
    }
    const cajaBaja = !!this.caja?.baja
    const accion = f => {
      if (f.baja || (f.id && cajaBaja)) return `<span class="badge" title="${this.esc(f.baja || this.caja?.baja)}">${T.etq.baja}</span>`
      if (f.id) return `<button type="button" class="text-stone-400 hover:text-red-700" title="${T.etq.baja_etiqueta_ayuda}" data-id="${f.id}" data-tipo="paquete" data-action="etiquetadora#darDeBaja"><i class="bi bi-trash"></i></button>`
      return this.porPieza ? "" : `<button type="button" class="text-stone-400 hover:text-red-700" title="${T.etq.quitar}" data-idx="${f.i}" data-action="etiquetadora#quitar"><i class="bi bi-x-lg"></i></button>`
    }
    const tachada = f => (f.baja || (f.id && cajaBaja)) ? "line-through text-stone-400" : ""
    this.listaTarget.innerHTML = filas.map(f => `<tr class="border-t border-stone-100 ${tachada(f)}">
        <td class="px-4 py-1 text-stone-400">${f.i + 1}</td>
        <td class="px-2 py-1 text-stone-500">${T.etq.origenes[f.origen] || f.origen}</td>
        <td class="px-2 py-1 text-right font-mono">${this.fmt(f.cantidad)} ${this.unidad}</td>
        <td class="px-2 py-1 font-mono text-xs ${f.codigo ? "text-emerald-700" : "italic text-stone-400"}">${f.codigo || T.etq.al_registrar}</td>
        <td class="px-2 py-1 text-right">${accion(f)}</td>
      </tr>`).join("")
    if (this.caja) {
      const c = this.caja
      this.listaTarget.insertAdjacentHTML("afterbegin", `<tr class="border-t border-amber-200 bg-amber-50 font-semibold ${cajaBaja ? "line-through text-stone-400" : ""}">
        <td class="px-4 py-1"><i class="bi bi-box-seam"></i></td><td class="px-2 py-1">${T.etq.caja}</td>
        <td class="px-2 py-1 text-right font-mono">${this.fmt(c.cantidad)} ${this.unidad}</td>
        <td class="px-2 py-1 font-mono text-xs text-amber-700">${c.codigo}</td>
        <td class="px-2 py-1 text-right">${cajaBaja ? `<span class="badge">${T.etq.baja}</span>` : `<button type="button" class="text-stone-400 hover:text-red-700" title="${T.etq.baja_caja_ayuda}" data-id="${c.id}" data-tipo="caja" data-action="etiquetadora#darDeBaja"><i class="bi bi-trash"></i></button>`}</td>
      </tr>`)
    }
    if (!filas.length && !this.caja) this.listaTarget.innerHTML = `<tr><td colspan="5" class="px-4 py-3 text-center text-xs text-stone-500">${this.porPieza && enCaja ? `${T.etq.caja_sin_individuales_a} ${n} ${T.etq.caja_sin_individuales_b}` : T.etq.sin_pesadas_aun}</td></tr>`
    this.btnRegistrarTarget.classList.toggle("hidden", this.registrado)
    this.btnReimprimirTarget.classList.toggle("hidden", !this.registrado || cajaBaja)
    this.pintarSalida()
  }

  pintarSalida() {
    if (!this.hasSalidaTarget) return
    const s = this.salida
    this.salidaTarget.innerHTML = s ? `→ ${T.etq.va_en_salida} <a href="${s.url}" class="chip-folio" target="_blank">${this.esc(s.folio)}</a> ${T.etq.a} ${this.esc(s.destino || "")} · ${s.paquetes} ${s.paquetes === 1 ? T.etq.paquete : T.etq.paquetes}` : ""
  }

  // Etiqueté mal: baja con motivo de una pesada o de la caja completa. El servidor la saca del
  // renglón del pedido y de la salida que se está armando; ya sellada, lo rechaza.
  async darDeBaja(e) {
    const { id, tipo } = e.currentTarget.dataset
    const motivo = prompt(`${T.dar_de_baja} ${tipo === "caja" ? T.etq.la_caja_completa_y_etiquetas : T.etq.esta_etiqueta}. ${T.etq.motivo_ejemplo}`)
    if (motivo === null) return
    if (motivo.trim().length < 3) { this.avisar(T.escribe_motivo); return }
    const d = await this.pedir(`${this.etiquetasUrlValue}/${id}/baja`, "POST", { motivo: motivo.trim() })
    if (!d) return
    if (tipo === "caja") {
      this.caja.baja = motivo
      this.pesadas.forEach(p => { if (p.id) p.baja = p.baja || motivo })
      this.resultadoTarget.textContent = `${T.etq.caja} ${d.codigo} ${T.etq.dada_de_baja}${d.hijas ? ` ${T.etq.con} ${d.hijas} ${T.etq.etiquetas}` : ""}`
    } else {
      this.pesadas.forEach(p => { if (p.id === Number(id)) p.baja = motivo })
      if (d.padre && this.caja?.id === d.padre.id) { this.caja.cantidad = d.padre.cantidad; if (d.padre.estado === "baja") this.caja.baja = T.etq.sin_paquetes }
      this.resultadoTarget.textContent = `${T.etq.etiqueta} ${d.codigo} ${T.etq.dada_de_baja}`
    }
    if (d.salida && this.salida) this.salida.paquetes = d.salida.paquetes
    this.actualizarLleva(d.lleva)
    this.pintarLista()
  }

  // ---------------------------------------------------------------- registrar e imprimir

  async registrar() {
    if (!this.producto) return
    const caja = this.enCajaTarget.checked
    let cuerpo
    if (this.porPieza) {
      const n = parseInt(this.piezasTarget.value) || 0
      if (n < 1) { this.avisar(T.etq.cuantas_piezas); return }
      cuerpo = caja ? { caja_fija: n } : { pesadas: Array.from({ length: n }, () => ({ cantidad: 1 })) }
    } else {
      if (!this.pesadas.length) { this.avisar(T.etq.no_hay_pesadas); return }
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
      this.resultadoTarget.textContent = this.caja ? `${T.etq.caja} ${this.caja.codigo} ${T.etq.registrada}` : `${datos.etiquetas.length} ${T.etq.etiquetas_registradas}`
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
    const ids = [ this.caja?.baja ? null : this.caja?.id, ...this.pesadas.filter(p => !p.baja).map(p => p.id) ].filter(Boolean)
    if (!ids.length) { this.avisar(T.etq.nada_registrado); return }
    this.imprimir({ ids: ids.join(",") })
  }

  copiasProveedor() {
    const n = parseInt(this.piezasTarget.value) || 0
    if (n < 1 || !this.producto?.codigos.length) return
    this.imprimir({ codigo: this.producto.codigos[0], n, nombre: this.producto.nombre, cantidad: this.pesoFijo > 0 ? `${this.pesoFijo.toFixed(3)} kg` : `1 ${T.etq.pz}` })
  }

  imprimir(extra) {
    const c = this.cfg()
    const url = `${this.imprimirUrlValue}?${new URLSearchParams({ ...extra, ancho: c.ancho, alto: c.alto, leyenda: c.leyenda, bc: c.barras, fn: c.letra, imprimir: 1 })}`
    if (!this.ventana || this.ventana.closed) this.ventana = window.open(url, "kobayashi_etiquetas", "width=480,height=420,popup")
    else this.ventana.location.href = url
    if (!this.ventana) this.avisar(T.etq.permite_popups)
  }

  async enviar(cuerpo) {
    const datos = await this.pedir(this.loteUrlValue, "POST", {
      producto_id: this.producto.id, pedido_linea_id: this.pedidoLineaIdValue, produccion_id: this.produccionIdValue,
      sustituto: this.sustitutoValue ? "1" : "",
      justificacion: this.hasJustificacionTarget ? this.justificacionTarget.value : "",
      ...cuerpo
    })
    if (datos?.salida) this.salida = datos.salida
    return datos
  }

  actualizarLleva(lleva) {
    const span = document.getElementById("lleva")
    if (span && lleva != null) span.textContent = lleva
  }

  // ---------------------------------------------------------------- báscula (Kana)

  iniciarBascula() {
    this.bascula = this.simuladaValue ? basculaSimulada() : new Bascula({ clave: "kobayashi:bascula" })
    const peso = (kg, color) => { this.pesoTarget.textContent = kg.toFixed(3); this.pesoTarget.className = `text-4xl font-extrabold leading-none ${color}` }
    this.bascula.on("peso", p => { peso(p.kg, p.kg > 0.02 ? "text-red-500" : "text-stone-500"); if (p.kg > 0.02) this.estadoTarget.textContent = `${T.etq.pesando} ${p.kg.toFixed(3)} kg` })
    this.bascula.on("estable", p => {
      if (this.producto && this.porKilo) { this.agregar(p.kg, "bascula"); peso(p.kg, "text-emerald-400"); this.estadoTarget.textContent = `${T.etq.agregado}: ${p.kg.toFixed(3)} kg ✓` }
      else this.estadoTarget.textContent = `${T.etq.estable} ${p.kg.toFixed(3)} kg (${T.etq.elige_producto_kilo})`
    })
    this.bascula.on("retirado", () => { peso(0, "text-stone-500"); this.estadoTarget.textContent = T.etq.coloca_paquete })
    this.bascula.on("estado", e => {
      const on = e.estado === "conectada"
      this.estadoTarget.textContent = e.mensaje || e.estado
      this.btnBasculaTarget.textContent = on ? T.etq.bascula_conectada : T.etq.conectar_bascula
      this.btnBasculaTarget.className = on ? "rounded border border-emerald-700 px-3 py-1 text-sm text-emerald-800 hover:bg-emerald-50" : "rounded border border-red-700 px-3 py-1 text-sm text-red-700 hover:bg-red-50"
      this.btnCapturarTarget.disabled = !on
    })
    this.bascula.on("aviso", a => { this.estadoTarget.textContent = a.mensaje || String(a) })
    // ?depurar=1 enseña la trama cruda bajo el peso, para ver qué manda la báscula cuando algo se atora.
    if (new URLSearchParams(location.search).has("depurar")) {
      this.bascula.on("trama", t => { this.estadoTarget.textContent = JSON.stringify(t.texto); console.debug("[báscula]", t.texto) })
    }
    if (!this.simuladaValue && Bascula.soportada) this.bascula.reconectar().catch(() => {})
    if (!this.simuladaValue && !Bascula.soportada) this.estadoTarget.textContent = T.etq.sin_web_serial
  }

  async alternarBascula() {
    if (this.bascula.conectada) {
      if (!confirm(T.etq.confirmar_desconectar)) return
      await this.bascula.desconectar()
    } else await this.bascula.conectar()
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

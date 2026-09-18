import { Controller } from "@hotwired/stimulus"
import { Bascula, basculaSimulada } from "kana"

// La etiquetadora al estilo de la pantalla /plus de Neotenia: se elige el producto, se arma un lote
// en uno de cuatro modos (individuales, caja virtual, caja con báscula real, código de fábrica),
// se ve el preview y con "Registrar + Imprimir" el servidor asigna los códigos de identidad y se
// imprimen. Los códigos nunca se inventan aquí: hasta registrar, el preview los muestra en gris.
export default class extends Controller {
  static targets = [
    "aviso", "buscador", "resultados",
    "infoCard", "infoNombre", "infoClave", "infoPlu", "infoUnidad", "infoPesoFijoChip", "infoPesoFijo",
    "infoCodigoChip", "infoCodigo", "infoLlevaChip", "infoLleva",
    "modosCard",
    "aCantidad", "aCantidadLabel", "aPesoCol", "aPeso", "aHint",
    "bTotalCol", "bTotal", "bPiezasLabel", "bPiezas", "bHint", "bIncluirCaja",
    "btnBasculaTexto", "btnCapturar", "cManual", "display", "peso", "estado", "cCount", "cTotal", "cLista", "cIncluirCaja", "cImprimirCada",
    "dEstado", "dCodigo", "dPesoLabel", "dPesoFijo", "btnVincular", "dResultado", "dArmarSin", "dArmarForm", "dCajaCantidad", "dCajaResultado",
    "pin", "justificacion",
    "previewCard", "previewCount", "preview", "btnRegistrar", "btnImprimir",
    "chipBascula", "chipBasculaTexto",
    "ajustes", "cfgAncho", "cfgAlto", "cfgLeyenda", "cfgBarras", "cfgLetra",
    "pedidos"
  ]
  static values = {
    loteUrl: String, productosUrl: String, imprimirUrl: String, vincularUrl: String,
    pedidoLineaId: String, produccionId: String, producto: Object,
    simulada: Boolean, puedeVincular: Boolean
  }

  CFG_CLAVE = "kobayashi:etiqueta_cfg"
  CFG_DEFAULT = { ancho: 55, alto: 45, leyenda: "", barras: 36, letra: 14 }

  connect() {
    this.producto = null
    this.modo = "A"
    this.pesadas = []       // [{ cantidad, origen: "bascula"|"manual", id?, codigo?, svg? }]
    this.items = []         // preview: [{ tipo: "paquete"|"caja", cantidad, id?, codigo?, svg?, pesada? }]
    this.registrado = false
    this.ventanaImpresion = null
    this.colaInstante = Promise.resolve()
    this.cargarCfg()
    this.iniciarBascula()
    this.pintarPesadas()
    document.querySelectorAll("button:not([type])").forEach(b => b.setAttribute("type", "button"))
    if (this.productoValue?.id) this.elegir(this.productoValue)
    else this.buscadorTarget.focus()
  }

  disconnect() {
    this.bascula?.desconectar().catch(() => {})
  }

  // ---------------------------------------------------------------- avisos

  avisar(texto, tipo = "error") {
    if (!texto) { this.avisoTarget.innerHTML = ""; return }
    this.avisoTarget.innerHTML = `<div class="alerta alerta-${tipo}">${this.esc(texto)}</div>`
    if (tipo !== "error") setTimeout(() => { if (this.avisoTarget.textContent.includes(texto)) this.avisoTarget.innerHTML = "" }, 4000)
  }

  esc(s) { return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])) }

  fmt(n, dec = 3) { return Number(n).toFixed(dec) }

  // ---------------------------------------------------------------- buscador

  async buscar() {
    const q = this.buscadorTarget.value.trim()
    const r = await fetch(`${this.productosUrlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
    if (!r.ok) return
    const lista = await r.json()
    if (this.buscadorTarget.value.trim() !== q) return
    this.candidatos = lista
    this.resultadosTarget.innerHTML = lista.length
      ? lista.map((p, i) => `<div class="buscador-item ${i === 0 ? "activo" : ""}" data-idx="${i}" data-action="mousedown->etiquetadora#elegirResultado"><strong>${this.esc(p.nombre)}</strong><small>${this.esc(p.clave)} · PLU ${p.plu}${p.codigos.length ? " · " + this.esc(p.codigos[0]) : ""}</small></div>`).join("")
      : `<div class="buscador-item text-slate-500">Sin resultados</div>`
    this.resultadosTarget.classList.remove("hidden")
    // Lector: un código exacto devuelve un solo producto; se toma sin más.
    if (lista.length === 1 && /^\d{8,}$/.test(q)) this.elegir(lista[0])
  }

  teclaBuscador(e) {
    if (e.key === "Escape") { this.resultadosTarget.classList.add("hidden"); return }
    if (e.key === "Enter") {
      e.preventDefault()
      const activo = this.resultadosTarget.querySelector(".buscador-item.activo")
      if (activo && this.candidatos) this.elegir(this.candidatos[Number(activo.dataset.idx)])
      return
    }
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
      const items = [ ...this.resultadosTarget.querySelectorAll(".buscador-item[data-idx]") ]
      if (!items.length) return
      let i = items.findIndex(el => el.classList.contains("activo"))
      i = e.key === "ArrowDown" ? Math.min(i + 1, items.length - 1) : Math.max(i - 1, 0)
      items.forEach(el => el.classList.remove("activo")); items[i].classList.add("activo"); items[i].scrollIntoView({ block: "nearest" })
    }
  }

  elegirResultado(e) {
    const idx = Number(e.currentTarget.dataset.idx)
    if (this.candidatos?.[idx]) this.elegir(this.candidatos[idx])
  }

  ocultarResultados() { setTimeout(() => this.resultadosTarget.classList.add("hidden"), 150) }

  elegir(p) {
    this.producto = p
    this.buscadorTarget.value = p.nombre
    this.resultadosTarget.classList.add("hidden")
    this.pintarInfo()
    this.modosCardTarget.classList.remove("hidden")
    this.limpiarPreview()
    this.pesadas = []; this.pintarPesadas()
    const pf = Number(p.peso_fijo || 0)
    this.aPesoTarget.value = pf > 0 ? this.fmt(pf) : ""
    this.aHintTarget.textContent = pf > 0 ? "Por defecto: peso fijo del producto" : "Ingresa el peso manualmente"
    this.adaptarPorUnidad()
    if (this.modo === "D") this.pintarEstadoD()
  }

  get porPieza() { return this.producto?.unidad === "pieza" }

  pintarInfo() {
    const p = this.producto
    this.infoCardTarget.classList.remove("hidden")
    this.infoNombreTarget.textContent = p.nombre
    this.infoClaveTarget.textContent = p.clave
    this.infoPluTarget.textContent = p.plu
    this.infoUnidadTarget.textContent = p.unidad
    const pf = Number(p.peso_fijo || 0)
    this.infoPesoFijoChipTarget.classList.toggle("hidden", !(pf > 0))
    this.infoPesoFijoTarget.textContent = this.fmt(pf)
    this.infoCodigoChipTarget.classList.toggle("hidden", !p.codigos.length)
    this.infoCodigoTarget.textContent = p.codigos.join(", ")
  }

  adaptarPorUnidad() {
    const pieza = this.porPieza
    this.aPesoColTarget.classList.toggle("hidden", pieza)
    this.aCantidadLabelTarget.textContent = pieza ? "Cantidad de piezas a etiquetar" : "Cantidad de etiquetas"
    if (pieza) this.aHintTarget.textContent = "Producto por pieza: cada etiqueta vale 1 pieza"
    this.bTotalColTarget.classList.toggle("hidden", pieza)
    this.bPiezasLabelTarget.textContent = pieza ? "Piezas en la caja" : "Piezas dentro de la caja"
    this.recalcularB()
  }

  // ---------------------------------------------------------------- modos

  cambiarModo(e) {
    const modo = e.currentTarget.dataset.modo
    this.modo = modo
    this.element.querySelectorAll(".plus-tab").forEach(t => t.classList.toggle("active", t.dataset.modo === modo))
    this.element.querySelectorAll(".plus-mode-body").forEach(b => b.classList.toggle("active", b.dataset.modoBody === modo))
    this.limpiarPreview()
    if (modo === "C") this.previewC()
    if (modo === "D") this.pintarEstadoD()
  }

  // MODO A: N etiquetas del mismo peso (o N piezas).
  generarA() {
    if (!this.producto) return
    const n = parseInt(this.aCantidadTarget.value) || 0
    const peso = this.porPieza ? 1 : Number(this.aPesoTarget.value) || 0
    if (n < 1) { this.avisar("Cantidad inválida"); return }
    if (!(peso > 0)) { this.avisar("Ingresa un peso válido"); return }
    this.items = Array.from({ length: n }, () => ({ tipo: "paquete", cantidad: peso }))
    this.registrado = false
    this.pintarPreview()
  }

  // MODO B: una caja con N pesadas virtuales iguales.
  recalcularB() {
    if (!this.hasBHintTarget) return
    const n = parseInt(this.bPiezasTarget.value) || 0
    if (this.porPieza) { this.bHintTarget.textContent = n > 0 ? `${n} piezas en la caja` : "—"; return }
    const total = Number(this.bTotalTarget.value) || 0
    this.bHintTarget.textContent = total > 0 && n > 0 ? `Peso por pieza: ${this.fmt(total / n)} kg` : "Peso por pieza: —"
  }

  generarB() {
    if (!this.producto) return
    const n = parseInt(this.bPiezasTarget.value) || 0
    let unit, total
    if (this.porPieza) { unit = 1; total = n }
    else { total = Number(this.bTotalTarget.value) || 0; unit = total / n }
    if (n < 1 || !(total > 0)) { this.avisar("Peso y piezas deben ser mayores que cero"); return }
    this.items = Array.from({ length: n }, () => ({ tipo: "paquete", cantidad: this.porPieza ? 1 : Number(this.fmt(unit)) }))
    if (this.bIncluirCajaTarget.checked) this.items.push({ tipo: "caja", cantidad: this.items.reduce((a, it) => a + it.cantidad, 0) })
    this.registrado = false
    this.pintarPreview()
  }

  // MODO C: pesadas reales, de la báscula o tecleadas.
  agregarManual() {
    const v = Number(this.cManualTarget.value) || 0
    if (!(v > 0)) { this.avisar("Peso inválido"); return }
    this.cManualTarget.value = ""
    this.agregarPesada(v, "manual")
  }

  agregarPesada(kg, origen) {
    if (!this.producto) { this.avisar("Selecciona un producto primero"); return }
    const pesada = { cantidad: this.porPieza ? 1 : Number(this.fmt(kg)), origen }
    this.pesadas.push(pesada)
    this.pintarPesadas()
    if (this.cImprimirCadaTarget.checked) this.registrarAlInstante(pesada)
  }

  quitarPesada(e) {
    const idx = Number(e.currentTarget.dataset.idx)
    const p = this.pesadas[idx]
    if (p?.id) { this.avisar(`La pesada ${p.codigo} ya está registrada; dala de baja desde Vivas si sobra`, "warn"); return }
    this.pesadas.splice(idx, 1)
    this.pintarPesadas()
  }

  limpiarPesadas() {
    if (!this.pesadas.length) return
    const registradas = this.pesadas.filter(p => p.id).length
    if (!confirm(`¿Limpiar ${this.pesadas.length} pesadas?${registradas ? ` ${registradas} ya están registradas y seguirán vivas.` : ""}`)) return
    this.pesadas = []
    this.pintarPesadas()
  }

  pintarPesadas() {
    if (!this.hasCListaTarget) return
    this.cCountTarget.textContent = this.pesadas.length
    this.cTotalTarget.textContent = this.fmt(this.pesadas.reduce((a, p) => a + p.cantidad, 0))
    this.cListaTarget.innerHTML = this.pesadas.length
      ? this.pesadas.map((p, i) => `<div class="pesada-item"><span class="idx">#${i + 1}</span><span class="origen">${p.origen === "bascula" ? "⚖ báscula" : "⌨ manual"}</span><span class="peso">${this.fmt(p.cantidad)} ${this.porPieza ? "pz" : "kg"}</span>${p.codigo ? `<span class="codigo">${p.codigo}</span>` : ""}<button type="button" class="btn btn-sm btn-outline-danger quitar" data-idx="${i}" data-action="etiquetadora#quitarPesada">✕</button></div>`).join("")
      : `<div class="py-3 text-center text-xs text-slate-500">Sin pesadas aún</div>`
    if (this.modo === "C") this.previewC()
  }

  previewC() {
    if (this.modo !== "C") return
    this.registrado = false
    if (!this.producto || !this.pesadas.length) { this.items = []; this.pintarPreview(); return }
    this.items = this.pesadas.map(p => ({ tipo: "paquete", cantidad: p.cantidad, id: p.id, codigo: p.codigo, svg: p.svg, pesada: p }))
    if (this.cIncluirCajaTarget.checked) this.items.push({ tipo: "caja", cantidad: this.pesadas.reduce((a, p) => a + p.cantidad, 0) })
    this.pintarPreview()
  }

  avisoImprimirCada() {
    if (this.cImprimirCadaTarget.checked) this.avisar("Cada pesada se registra y se imprime al momento con su código definitivo. La caja se arma al final con Registrar + Imprimir.", "info")
  }

  // Cada pesada capturada se registra sola (código definitivo) y se imprime; la caja llega al final.
  registrarAlInstante(pesada) {
    this.colaInstante = this.colaInstante.then(async () => {
      const datos = await this.enviarLote({ pesadas: [ { cantidad: pesada.cantidad } ] })
      if (!datos) return
      Object.assign(pesada, datos.etiquetas[0])
      this.actualizarLleva(datos.lleva)
      this.pintarPesadas()
      this.imprimirIds([ pesada.id ])
    })
  }

  // MODO D: código de fábrica y cajas de N piezas.
  pintarEstadoD() {
    const p = this.producto
    if (!p) { this.dEstadoTarget.innerHTML = `<div class="text-xs text-slate-500">Selecciona un producto primero.</div>`; return }
    this.dCodigoTarget.value = ""
    this.dPesoFijoTarget.value = Number(p.peso_fijo || 0) > 0 ? this.fmt(p.peso_fijo) : ""
    this.dPesoLabelTarget.innerHTML = (p.unidad === "kg" ? "Peso fijo (kg)" : "Peso por pieza (kg)") + ' <span class="text-slate-400">opcional</span>'
    const tiene = p.codigos.length > 0
    this.dArmarFormTarget.classList.toggle("hidden", !tiene)
    this.dArmarSinTarget.classList.toggle("hidden", tiene)
    this.dEstadoTarget.innerHTML = tiene
      ? `<div class="alerta alerta-ok">✔ Códigos ligados: ${p.codigos.map(c => `<code>${this.esc(c)}</code>`).join(", ")}</div>`
      : `<div class="alerta alerta-secondary">⊖ Sin código fijo asignado.</div>`
    if (!this.puedeVincularValue) {
      this.btnVincularTarget.disabled = true
      this.btnVincularTarget.title = "Hace falta el permiso admin.catalogo"
    }
  }

  ean13Check(base12) {
    let s = 0
    for (let i = 0; i < 12; i++) s += Number(base12[i]) * (i % 2 === 0 ? 1 : 3)
    return String((10 - (s % 10)) % 10)
  }

  // EAN-13 interno con prefijo 29 (uso interno GS1) + PLU + 00000, para lo que no trae código.
  generarInterno() {
    if (!this.producto) { this.avisar("Selecciona un producto primero"); return }
    const base = "29" + String(this.producto.plu).padStart(5, "0") + "00000"
    this.dCodigoTarget.value = base + this.ean13Check(base)
    this.avisar("Código generado; pulsa Vincular para guardarlo", "ok")
  }

  async vincular() {
    if (!this.producto) return
    const codigo = this.dCodigoTarget.value.trim()
    const peso = this.dPesoFijoTarget.value.trim()
    if (!codigo && !peso) { this.avisar("Ingresa un código o un peso fijo"); return }
    const r = await this.post(this.vincularUrlValue, { producto_id: this.producto.id, codigo, peso_fijo: peso })
    const d = await r.json()
    if (!r.ok) { this.avisar(d.error || "No se pudo vincular"); return }
    this.producto = d
    this.pintarInfo()
    this.pintarEstadoD()
    this.dResultadoTarget.innerHTML = `<div class="alerta alerta-ok">✔ Vinculado${codigo ? ` · código <code>${this.esc(codigo)}</code>` : ""}${peso ? ` · peso fijo ${this.fmt(peso)} kg` : ""}</div>`
  }

  async armarCajaFija() {
    if (!this.producto) return
    const n = parseInt(this.dCajaCantidadTarget.value) || 0
    if (n < 1) { this.avisar("Indica la cantidad de piezas"); return }
    const datos = await this.enviarLote({ caja_fija: n })
    if (!datos) return
    this.actualizarLleva(datos.lleva)
    const caja = datos.caja
    this.dCajaResultadoTarget.innerHTML = `<div class="alerta alerta-ok">✔ Caja armada · ${this.fmt(caja.cantidad, 0)} piezas · código <code>${caja.codigo}</code></div>
      <button type="button" class="btn btn-sm btn-outline" data-action="etiquetadora#reimprimirCaja" data-id="${caja.id}">🖨 Reimprimir etiqueta</button>`
    this.imprimirIds([ caja.id ])
  }

  reimprimirCaja(e) { this.imprimirIds([ Number(e.currentTarget.dataset.id) ]) }

  // Solo imprime N etiquetas con el código de fábrica, sin registrar nada.
  soloEtiquetasFijas() {
    if (!this.producto?.codigos.length) { this.avisar("El producto no tiene código fijo"); return }
    const n = parseInt(this.dCajaCantidadTarget.value) || 0
    if (n < 1) { this.avisar("Indica cuántas etiquetas quieres"); return }
    const pf = Number(this.producto.peso_fijo || 0)
    this.abrirImpresion({ codigo: this.producto.codigos[0], n, nombre: this.producto.nombre, cantidad: pf > 0 ? `${this.fmt(pf)} kg` : "1 pz" })
  }

  // ---------------------------------------------------------------- preview

  limpiarPreview() {
    this.items = []
    this.registrado = false
    this.previewCardTarget.classList.add("hidden")
    this.previewTarget.innerHTML = ""
  }

  pintarPreview() {
    if (!this.items.length) { this.previewCardTarget.classList.add("hidden"); return }
    this.previewCardTarget.classList.remove("hidden")
    this.previewCountTarget.textContent = this.items.length
    this.btnRegistrarTarget.classList.toggle("hidden", this.registrado)
    this.btnImprimirTarget.classList.toggle("hidden", !this.registrado)
    const ordenados = [ ...this.items ].sort((a, b) => (a.tipo === "caja" ? -1 : 0) - (b.tipo === "caja" ? -1 : 0))
    const unidad = this.porPieza ? "pz" : "kg"
    this.previewTarget.innerHTML = ordenados.map((it, i) => {
      const barcode = it.svg ? it.svg : `<div class="pendiente"></div><div class="pendiente-texto">${it.codigo || "código al registrar"}</div>`
      return `<div class="preview-etq ${it.tipo === "caja" ? "tipo-caja" : ""}" title="${it.tipo === "caja" ? "Etiqueta de caja" : "Etiqueta " + (i + 1)}">
        <div class="nombre-mini">${this.esc(this.producto?.nombre || "")}</div>${barcode}
        <div class="peso-mini">${this.fmt(it.cantidad, this.porPieza ? 0 : 3)} ${unidad}</div></div>`
    }).join("")
  }

  // ---------------------------------------------------------------- registrar e imprimir

  async registrarImprimir() {
    if (!this.producto || !this.items.length) return
    if (this.registrado) { this.avisar("Este lote ya está registrado; solo se reimprime", "info"); this.soloImprimir(); return }
    const paquetes = this.items.filter(it => it.tipo === "paquete")
    const caja = this.items.some(it => it.tipo === "caja")
    this.btnRegistrarTarget.disabled = true
    try {
      const datos = await this.enviarLote({
        pesadas: paquetes.map(it => it.id ? { id: it.id } : { cantidad: it.cantidad }),
        caja: caja ? "1" : ""
      })
      if (!datos) return
      paquetes.forEach((it, i) => { Object.assign(it, datos.etiquetas[i]); if (it.pesada) Object.assign(it.pesada, datos.etiquetas[i]) })
      const itemCaja = this.items.find(it => it.tipo === "caja")
      if (itemCaja && datos.caja) Object.assign(itemCaja, datos.caja)
      this.registrado = true
      this.actualizarLleva(datos.lleva)
      this.avisar(`${datos.etiquetas.length} etiquetas registradas${datos.caja ? ` en la caja ${datos.caja.codigo}` : ""}`, "ok")
      this.pintarPreview()
      if (this.modo === "C") { this.pesadas = []; this.pintarPesadasSinPreview() }
      this.soloImprimir()
    } finally {
      this.btnRegistrarTarget.disabled = false
    }
  }

  pintarPesadasSinPreview() {
    const modo = this.modo; this.modo = "-"; this.pintarPesadas(); this.modo = modo
  }

  soloImprimir() {
    const ids = [ ...this.items ].sort((a, b) => (a.tipo === "caja" ? -1 : 0) - (b.tipo === "caja" ? -1 : 0)).map(it => it.id).filter(Boolean)
    if (!ids.length) { this.avisar("Nada registrado todavía"); return }
    this.imprimirIds(ids)
  }

  imprimirIds(ids) { this.abrirImpresion({ ids: ids.join(",") }) }

  abrirImpresion(extra) {
    const cfg = this.cfg()
    const q = new URLSearchParams({ ...extra, ancho: cfg.ancho, alto: cfg.alto, leyenda: cfg.leyenda, bc: cfg.barras, fn: cfg.letra, imprimir: 1 })
    const url = `${this.imprimirUrlValue}?${q}`
    if (!this.ventanaImpresion || this.ventanaImpresion.closed) {
      this.ventanaImpresion = window.open(url, "kobayashi_etiquetas", "width=480,height=420,popup")
    } else {
      this.ventanaImpresion.location.href = url
    }
    if (!this.ventanaImpresion) this.avisar("Permite las ventanas emergentes para imprimir", "warn")
  }

  async enviarLote(cuerpo) {
    const r = await this.post(this.loteUrlValue, {
      producto_id: this.producto.id, pedido_linea_id: this.pedidoLineaIdValue, produccion_id: this.produccionIdValue,
      pin: this.hasPinTarget ? this.pinTarget.value : "", justificacion: this.hasJustificacionTarget ? this.justificacionTarget.value : "",
      ...cuerpo
    })
    const datos = await r.json()
    if (!r.ok) { this.avisar(datos.error || "No se pudo registrar"); return null }
    this.avisar("")
    return datos
  }

  post(url, cuerpo) {
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: JSON.stringify(cuerpo)
    })
  }

  actualizarLleva(lleva) {
    if (lleva == null) return
    const span = document.getElementById("lleva")
    if (span) span.textContent = lleva
    this.infoLlevaChipTarget.classList.remove("hidden")
    this.infoLlevaTarget.textContent = lleva
  }

  // ---------------------------------------------------------------- báscula (Kana)

  iniciarBascula() {
    this.bascula = this.simuladaValue ? basculaSimulada() : new Bascula({ clave: "kobayashi:bascula" })
    this.bascula.on("peso", p => {
      this.pesoTarget.textContent = this.fmt(p.kg)
      this.pesoTarget.style.color = p.kg > 0.02 ? "#C8161D" : "#787878"
      if (!this.bascula.estable && p.kg > 0.02 && !this.yaCapturado) this.estadoBascula(`Pesando… ${this.fmt(p.kg)} kg`, "#3b82f6")
    })
    this.bascula.on("estable", p => {
      this.yaCapturado = true
      this.pesoTarget.style.color = "#16a34a"
      this.estadoBascula(`Agregado: ${this.fmt(p.kg)} kg ✓`, "#16a34a")
      if (this.modo === "C" && this.producto && !this.porPieza) this.agregarPesada(p.kg, "bascula")
    })
    this.bascula.on("retirado", () => { this.yaCapturado = false; this.pesoTarget.textContent = "0.000"; this.estadoBascula("Coloca paquete", "#aaa") })
    this.bascula.on("estado", e => {
      const conectada = e.estado === "conectada"
      this.displayTarget.classList.toggle("hidden", !conectada)
      this.btnCapturarTarget.disabled = !conectada
      this.btnBasculaTextoTarget.textContent = conectada ? "Desconectar" : "Conectar báscula"
      this.chipBasculaTarget.classList.toggle("btn-outline-danger", !conectada)
      this.chipBasculaTarget.classList.toggle("btn-outline-success", conectada)
      this.chipBasculaTextoTarget.textContent = conectada ? "Báscula conectada" : "Conectar báscula"
      this.estadoBascula(e.mensaje || e.estado, conectada ? "#aaa" : "#f59e0b")
      if (e.mensaje && !conectada) this.avisar(e.mensaje, "warn")
    })
    this.bascula.on("aviso", a => this.avisar(a.mensaje || String(a), "warn"))
    if (!this.simuladaValue && Bascula.soportada) this.bascula.reconectar().catch(() => {})
    if (!this.simuladaValue && !Bascula.soportada) this.chipBasculaTextoTarget.textContent = "Sin Web Serial (usa Chrome o Edge)"
  }

  estadoBascula(texto, color) {
    this.estadoTarget.textContent = texto
    this.estadoTarget.style.color = color
  }

  async alternarBascula() {
    if (this.bascula.conectada) {
      if (!confirm("¿Desconectar la báscula? La próxima vez tendrás que elegir el puerto de nuevo.")) return
      await this.bascula.desconectar()
    } else {
      await this.bascula.conectar()
    }
  }

  capturarAhora() {
    const kg = this.bascula.peso
    if (!(kg > 0)) { this.avisar("Peso en cero", "warn"); return }
    if (!this.bascula.estable && !confirm("Báscula aún no estable. ¿Capturar de todas formas?")) return
    this.agregarPesada(kg, "bascula")
  }

  simular() {
    const kg = Math.round((0.3 + Math.random() * 2.5) * 1000) / 1000
    this.bascula.simulador.colocar(kg)
    setTimeout(() => this.bascula.simulador.retirar(), 2500)
  }

  // ---------------------------------------------------------------- ajustes de etiqueta

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

  guardarCfg() {
    try { localStorage.setItem(this.CFG_CLAVE, JSON.stringify(this.cfg())) } catch { /* sin storage */ }
  }

  restablecerCfg() {
    try { localStorage.removeItem(this.CFG_CLAVE) } catch { /* sin storage */ }
    this.cargarCfg()
  }

  abrirAjustes() { this.ajustesTarget.classList.remove("hidden") }
  cerrarAjustes() { this.ajustesTarget.classList.add("hidden") }
  abrirPedidos() { this.pedidosTarget.classList.remove("hidden") }
  cerrarPedidos() { this.pedidosTarget.classList.add("hidden") }
  cerrarPanelFuera(e) { if (e.target === e.currentTarget) e.currentTarget.classList.add("hidden") }
}

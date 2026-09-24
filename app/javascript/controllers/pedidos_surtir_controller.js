import { Controller } from "@hotwired/stimulus"

// "Pedidos por surtir" dentro de la etiquetadora: un diálogo con la cola de pedidos y, por pedido,
// el checklist de renglones con sus bultos (en qué salida van, si ya los verificó otra persona),
// Surtir (manda a etiquetar ese renglón), sustituto, no surtir, y dar de baja lo etiquetado mal.
// El envío no sale de aquí: se sella y se envía en la salida, que la verifica otra persona.
export default class extends Controller {
  static targets = [ "dialogo", "titulo", "cuerpo", "pie", "faltan", "salidaLink" ]
  static values = { pedidosUrl: String, etiquetarUrl: String, etiquetasUrl: String, productosUrl: String }

  connect() {
    const id = new URLSearchParams(location.search).get("pedido")
    if (id) this.abrir({ params: { id: Number(id) } })
  }

  esc(s) { return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])) }
  color(nombre) { let h = 0; for (const c of String(nombre || "").toUpperCase()) h = (h * 31 + c.charCodeAt(0)) % 360; return `hsl(${h}, 65%, 38%)` }
  chip(nombre, grande = false) { return `<span class="inline-block whitespace-nowrap rounded-lg font-extrabold text-white ${grande ? "px-3 py-1 text-sm" : "px-2 py-0.5 text-xs"}" style="background:${this.color(nombre)}">${this.esc(String(nombre || "?").toUpperCase())}</span>` }

  async pedir(url, metodo = "GET", cuerpo) {
    const r = await fetch(url, {
      method: metodo,
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: cuerpo ? JSON.stringify(cuerpo) : undefined
    })
    const datos = await r.json().catch(() => ({}))
    if (!r.ok) { alert(datos.error || T.no_se_pudo); return null }
    return datos
  }

  abrir(e) {
    const id = e?.params?.id
    if (!this.dialogoTarget.open) this.dialogoTarget.showModal()
    id ? this.detalle(id) : this.lista()
  }

  cerrar() { this.dialogoTarget.close() }
  cerrarFuera(e) { if (e.target === this.dialogoTarget) this.cerrar() }

  // ---------------------------------------------------------------- lista

  async lista() {
    this.pedido = null
    this.tituloTarget.textContent = T.pedidos_por_surtir
    this.pieTarget.classList.add("hidden")
    this.cuerpoTarget.innerHTML = `<p class="py-4 text-center text-sm text-stone-500">${T.cargando}</p>`
    const d = await this.pedir(`${this.pedidosUrlValue}.json`)
    if (!d) return
    if (!d.pedidos.length) { this.cuerpoTarget.innerHTML = `<p class="py-6 text-center text-stone-500">${T.sin_pedidos}</p>`; return }
    this.cuerpoTarget.innerHTML = d.pedidos.map(p => `
      <div class="flex cursor-pointer items-center gap-3 border-b border-dashed border-stone-200 py-2 pl-3 hover:bg-stone-50" style="border-left:6px solid ${this.color(p.destino)}" data-action="click->pedidos-surtir#abrir" data-pedidos-surtir-id-param="${p.id}">
        <span class="text-lg" style="color:${this.color(p.destino)}"><i class="bi bi-basket"></i></span>
        <div class="flex-1">
          <div class="flex flex-wrap items-center gap-2"><strong class="text-base">${this.esc(p.folio)}</strong> ${this.chip(p.destino, true)}
            <span class="text-xs text-stone-500">${this.esc(p.usuario)} · ${this.esc(p.creado)}</span></div>
          ${p.notas ? `<div class="mt-1 text-xs text-stone-500">${this.esc(p.notas)}</div>` : ""}
        </div>
        <span class="rounded px-2 py-0.5 text-xs ${p.estado === "surtiendo" ? "bg-amber-100 text-amber-800" : "bg-sky-100 text-sky-800"}">${T.estados[p.estado] || p.estado} · ${p.resueltos}/${p.renglones}</span>
        <span class="text-stone-400">›</span>
      </div>`).join("")
  }

  // ---------------------------------------------------------------- detalle

  async detalle(id) {
    this.cuerpoTarget.innerHTML = `<p class="py-4 text-center text-sm text-stone-500">${T.cargando}</p>`
    const d = await this.pedir(`${this.pedidosUrlValue}/${id}.json`)
    if (!d) return
    this.pedido = d
    this.pintar()
  }

  refrescar() { if (this.pedido) this.detalle(this.pedido.pedido.id) }

  pintar() {
    const { pedido: p, renglones, salida } = this.pedido
    const abierto = p.abierto
    this.tituloTarget.innerHTML = `${this.esc(p.folio)} &nbsp;${this.chip(p.destino, true)}`
    const bulto = (r, b) => {
      const enviada = b.salida && b.salida.estado !== "preparando"
      const badge = !b.salida ? `<span class="text-xs text-amber-700">${T.sin_salida}</span>`
        : enviada ? `<span class="rounded bg-emerald-100 px-1.5 py-0.5 text-xs text-emerald-800"><i class="bi bi-truck"></i> ${this.esc(b.salida.folio)} ${T.estados[b.salida.estado] || b.salida.estado}</span>`
        : `<span class="rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800"><i class="bi bi-box-seam"></i> ${this.esc(b.salida.folio)} ${T.por_enviar}</span>`
      const verif = b.verificada ? `<span class="text-xs text-emerald-700">✓ ${T.verificada}</span>` : (b.salida && !enviada ? `<span class="text-xs text-amber-700">${T.sin_verificar}</span>` : "")
      const baja = abierto && !enviada ? `<button type="button" class="btn btn-ghost-danger btn-xs ml-auto" title="${T.baja_ayuda}" data-id="${b.id}" data-que="${b.tipo === "caja" ? T.la_caja_completa : T.el_paquete}" data-action="pedidos-surtir#darDeBaja"><i class="bi bi-trash"></i> ${T.dar_de_baja}</button>` : ""
      return `<div class="flex flex-wrap items-center gap-2 py-0.5 pl-6 text-xs">
        <code>${this.esc(b.codigo)}</code>
        <span class="text-stone-500">${b.tipo}${b.paquetes ? ` · ${b.paquetes} ${T.paq}` : ""} · ${this.esc(b.cantidad)} ${r.unidad}</span>
        ${b.sustituto ? `<span class="rounded bg-violet-600 px-1.5 py-0.5 text-white">${T.sustituto}: ${this.esc(b.sustituto)}</span>` : ""}
        ${badge} ${verif} ${baja}</div>`
    }
    const html = renglones.map(r => {
      const ico = r.estado === "surtido" ? `<i class="bi bi-check-circle-fill text-emerald-600"></i>` : r.estado === "no_surtir" ? `<i class="bi bi-slash-circle text-stone-400"></i>` : `<i class="bi bi-circle text-amber-500"></i>`
      const acciones = !abierto ? "" : `<div class="mt-1 flex flex-wrap gap-2">
        ${r.estado !== "no_surtir" ? `<a class="btn btn-primary btn-xs" href="${this.etiquetarUrlValue}?pedido_linea_id=${r.id}"><i class="bi bi-tag"></i> ${T.surtir}</a>
          <button type="button" class="btn btn-warning btn-xs" data-id="${r.id}" data-action="pedidos-surtir#sustituto"><i class="bi bi-arrow-left-right"></i> ${T.enviar_sustituto}</button>
          ${r.estado === "pendiente" ? `<button type="button" class="btn btn-secondary btn-xs" data-id="${r.id}" data-action="pedidos-surtir#surtido" title="${T.dar_por_surtido_ayuda}">${T.dar_por_surtido}</button>` : ""}` : ""}
        <button type="button" class="btn btn-secondary btn-xs" data-id="${r.id}" data-action="pedidos-surtir#${r.estado === "no_surtir" ? "reabrir" : "noSurtir"}">${r.estado === "no_surtir" ? T.reactivar : T.no_se_va_a_surtir}</button>
        </div>
        <div class="mt-1 hidden max-w-md" id="sus-${r.id}">
          <input type="text" class="w-full rounded border border-stone-300 px-2 py-1 text-sm" placeholder="${T.buscar_sustituto}" data-id="${r.id}" data-action="input->pedidos-surtir#buscarSustituto">
          <div class="max-h-40 overflow-auto text-sm" id="sus-res-${r.id}"></div>
        </div>`
      return `<div class="border-b border-dashed border-stone-200 py-2">
        <div class="flex flex-wrap items-center gap-2">${ico} <strong>${this.esc(r.producto)}</strong>
          <span class="ml-auto text-sm font-mono">${this.esc(r.surtida)} / ${this.esc(r.cantidad)} ${r.unidad}</span></div>
        <div class="my-1 h-1.5 overflow-hidden rounded bg-stone-200"><span class="block h-full bg-emerald-600" style="width:${r.pct}%"></span></div>
        ${r.motivo ? `<div class="pl-6 text-xs text-stone-500">${this.esc(r.motivo)}</div>` : ""}
        ${r.bultos.map(b => bulto(r, b)).join("")}
        ${acciones}</div>`
    }).join("")
    this.cuerpoTarget.innerHTML = html || `<p class="py-4 text-stone-500">${T.sin_renglones}</p>`
    this.pieTarget.classList.toggle("hidden", !abierto)
    if (!abierto) return
    const faltan = renglones.filter(r => r.estado === "pendiente").map(r => `${r.producto}: ${T.sin_surtir}`)
    renglones.forEach(r => { const n = r.bultos.filter(b => b.salida?.estado === "preparando" && !b.verificada).length; if (n) faltan.push(`${r.producto}: ${n} ${n === 1 ? T.bulto : T.bultos} ${T.sin_verificar}`) })
    this.faltanTarget.textContent = faltan.length ? `⚠ ${faltan.join(" · ")}` : (salida ? T.todo_listo : "")
    this.salidaLinkTarget.classList.toggle("hidden", !salida)
    if (salida) {
      this.salidaLinkTarget.href = salida.url
      this.salidaLinkTarget.innerHTML = `<i class="bi bi-truck"></i> ${this.esc(salida.folio)}: ${salida.sin_verificar ? `${T.verificar} (${salida.sin_verificar}) ${T.y_enviar}` : T.sellar_y_enviar}`
    }
  }

  // ---------------------------------------------------------------- acciones

  linea(e) { return `${this.pedidosUrlValue}/${this.pedido.pedido.id}/lineas/${e.currentTarget.dataset.id}` }

  async noSurtir(e) {
    const motivo = prompt(T.por_que_no_surtir)
    if (motivo === null) return
    if (await this.pedir(`${this.linea(e)}/no_surtir`, "POST", { motivo })) this.refrescar()
  }

  async reabrir(e) { if (await this.pedir(`${this.linea(e)}/reabrir`, "POST", {})) this.refrescar() }

  async surtido(e) {
    if (!confirm(T.confirmar_surtido)) return
    if (await this.pedir(`${this.linea(e)}/surtido`, "POST", {})) this.refrescar()
  }

  async darDeBaja(e) {
    const { id, que } = e.currentTarget.dataset
    const motivo = prompt(`${T.dar_de_baja} ${que}. ${T.motivo_pregunta}`)
    if (motivo === null) return
    if (motivo.trim().length < 3) { alert(T.escribe_motivo); return }
    if (await this.pedir(`${this.etiquetasUrlValue}/${id}/baja`, "POST", { motivo: motivo.trim() })) this.refrescar()
  }

  sustituto(e) {
    const caja = document.getElementById(`sus-${e.currentTarget.dataset.id}`)
    caja.classList.toggle("hidden")
    if (!caja.classList.contains("hidden")) caja.querySelector("input").focus()
  }

  buscarSustituto(e) {
    clearTimeout(this.timerSustituto)
    const id = e.currentTarget.dataset.id, q = e.currentTarget.value.trim()
    const res = document.getElementById(`sus-res-${id}`)
    if (q.length < 2) { res.innerHTML = ""; return }
    this.timerSustituto = setTimeout(async () => {
      const r = await fetch(`${this.productosUrlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
      const items = r.ok ? await r.json() : []
      res.innerHTML = items.slice(0, 8).map(p => `<a class="block cursor-pointer border-b border-dashed border-stone-200 px-2 py-1 hover:bg-stone-100" href="${this.etiquetarUrlValue}?pedido_linea_id=${id}&producto_id=${p.id}&sustituto=1"><strong>${this.esc(p.nombre)}</strong> <span class="text-xs text-stone-500">${this.esc(p.clave)} · ${p.unidad}</span></a>`).join("") || `<p class="p-2 text-stone-500">${T.sin_resultados}</p>`
    }, 250)
  }
}

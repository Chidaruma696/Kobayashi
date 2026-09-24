import { Controller } from "@hotwired/stimulus"

// Da de baja una etiqueta por su código: busca el id y manda el formulario a /etiquetas/:id/baja.
export default class extends Controller {
  static targets = ["codigo", "motivo"]

  async enviar() {
    const codigo = this.codigoTarget.value.trim()
    const motivo = this.motivoTarget.value.trim()
    if (!codigo || !motivo) { alert(T.baja.faltan_codigo_y_motivo); return }
    const r = await fetch(`/etiquetas/buscar?codigo=${encodeURIComponent(codigo)}`, { headers: { Accept: "application/json" } })
    if (!r.ok) { alert(T.baja.no_encontrada); return }
    const { id } = await r.json()
    const form = document.createElement("form")
    form.method = "post"
    form.action = `/etiquetas/${id}/baja`
    const token = document.querySelector("meta[name=csrf-token]").content
    for (const [k, v] of [["authenticity_token", token], ["motivo", motivo]]) {
      const i = document.createElement("input"); i.type = "hidden"; i.name = k; i.value = v; form.appendChild(i)
    }
    document.body.appendChild(form)
    form.submit()
  }
}

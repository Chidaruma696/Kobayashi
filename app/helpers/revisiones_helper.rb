module RevisionesHelper
  # A dónde lleva la operación revisada.
  def enlace_de_revision(revision)
    r = revision.revisable
    case r
    when Etiqueta then etiqueta_path(r)
    when Produccion then produccion_path(r)
    when SalidaLinea then salida_path(r.salida)
    when Movimiento then kardex_inventario_path(producto_id: r.producto_id, sucursal_id: r.sucursal_id)
    when Retiro then caja_corte_path
    else revisiones_path
    end
  end
end

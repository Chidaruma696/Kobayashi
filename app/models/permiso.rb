# Claves de permiso. Un rol tiene una lista de claves; "*" lo permite todo y "caja.*" todo un módulo.
module Permiso
  CLAVES = {
    "caja.vender" => "Vender en caja",
    "caja.abrir" => "Abrir y cerrar caja",
    "caja.retirar" => "Retirar efectivo a caja fuerte",
    "caja.bajar_precio" => "Autorizar un precio por debajo del catálogo",
    "caja.devolver" => "Recibir devoluciones de clientes",
    "etiquetas.crear" => "Etiquetar paquetes, cajas y tarimas (sobre pedido o producción)",
    "etiquetas.libre" => "Autorizar etiquetar o producir sin pedido",
    "pedidos.solicitar" => "Pedir mercancía a la matriz",
    "pedidos.surtir" => "Surtir pedidos y cerrar renglones",
    "produccion.abrir" => "Abrir y cerrar producciones",
    "inventario.ver" => "Ver existencias y movimientos",
    "inventario.ajustar" => "Ajustar existencias con justificación",
    "salidas.surtir" => "Surtir salidas a ruta o tienda",
    "salidas.verificar" => "Verificar la carga antes de salir",
    "salidas.recibir" => "Recibir salidas en tienda",
    "conteos.hacer" => "Hacer conteos físicos",
    "admin.catalogo" => "Administrar productos y códigos",
    "admin.usuarios" => "Administrar usuarios, roles y sucursales"
  }.freeze

  MODULOS = CLAVES.keys.map { |c| c.split(".").first }.uniq.freeze

  def self.valida?(clave)
    clave == "*" || CLAVES.key?(clave) || (clave.end_with?(".*") && MODULOS.include?(clave.delete_suffix(".*")))
  end

  # ¿La lista de claves de un rol cubre esta clave?
  def self.cubre?(permisos, clave)
    return false unless CLAVES.key?(clave)
    modulo = clave.split(".").first
    permisos.include?("*") || permisos.include?(clave) || permisos.include?("#{modulo}.*")
  end
end

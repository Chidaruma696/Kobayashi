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
    "rutas.armar" => "Armar viajes de reparto y despacharlos",
    "rutas.repartir" => "Repartir: entregar, rechazar y cobrar en la parada (chofer)",
    "rutas.liquidar" => "Liquidar el viaje del chofer al volver",
    "cobranza.ver" => "Ver saldos, antigüedad y estados de cuenta",
    "cobranza.abonar" => "Registrar abonos de clientes en oficina",
    "cobranza.bloquear" => "Bloquear o desbloquear el crédito a mano",
    "canastillas.ver" => "Ver saldos de canastillas por cliente y chofer",
    "canastillas.ajustar" => "Registrar devoluciones y ajustes de canastillas",
    "conteos.hacer" => "Hacer conteos físicos y cargar faltantes",
    "conteos.cargos" => "Cobrar o perdonar cargos",
    "reportes.ver" => "Ver el tablero y los reportes",
    "revisiones.resolver" => "Revisar lo que se hizo sin autorización (aprobar, observar, cargar)",
    "compras.ver" => "Ver proveedores, cuentas por pagar y envases",
    "compras.recibir" => "Recibir mercancía del proveedor",
    "compras.facturar" => "Capturar y cancelar facturas del proveedor",
    "compras.pagar" => "Pagar a proveedores desde la caja",
    "admin.catalogo" => "Administrar productos y códigos",
    "admin.usuarios" => "Administrar usuarios, roles y sucursales"
  }.freeze

  MODULOS = CLAVES.keys.map { |c| c.split(".").first }.uniq.freeze

  # Nombre para mostrar, en el idioma del usuario (permisos.* en config/locales).
  def self.nombre(clave)
    # La clave lleva punto, así que no se puede pedir "permisos.caja.vender" (I18n lo anidaría).
    I18n.t("permisos", default: {})[clave.to_sym] || CLAVES[clave]
  end

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

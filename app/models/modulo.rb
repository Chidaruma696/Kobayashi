# Módulos que se encienden o apagan por negocio (el mapa completo está en docs/arquitectura.md).
# Caja, inventario, administración y ajustes van siempre; el resto depende del giro elegido al
# arrancar y se puede cambiar después en Ajustes. Cada módulo es un conjunto aparte: sus tablas,
# sus permisos, su pestaña. Rutas necesita pedidos y salidas (un reparto es una salida a un cliente
# que pidió); retornables necesita compras (los envases son de un proveedor).
module Modulo
  OPCIONALES = %w[compras retornables almacenes etiquetas pedidos salidas rutas conteos].freeze
  DEPENDE = { "rutas" => %w[pedidos salidas], "retornables" => %w[compras] }.freeze
  # Prefijos de permiso que cuelgan de cada módulo (los demás permisos van siempre).
  PERMISOS = { "compras" => %w[compras], "retornables" => %w[retornables], "almacenes" => %w[almacenes],
               "etiquetas" => %w[etiquetas produccion], "pedidos" => %w[pedidos], "salidas" => %w[salidas],
               "rutas" => %w[rutas cobranza canastillas], "conteos" => %w[conteos] }.freeze
  # Preset por giro; "todo" es el negocio para el que nació el sistema.
  GIROS = {
    "abarrotes" => %w[compras],
    "recauderia" => %w[compras etiquetas],
    "distribuidora" => %w[compras retornables almacenes pedidos salidas rutas conteos],
    "todo" => OPCIONALES
  }.freeze

  def self.activo?(clave)
    return true unless OPCIONALES.include?(clave.to_s)
    activos.include?(clave.to_s)
  end

  # Se lee una vez por petición (Current) para no consultar la tabla en cada botón de la cinta.
  def self.activos
    Current.modulos ||= OPCIONALES.select { |m| Ajuste["modulos.#{m}"] == "1" }
  end

  def self.permiso_activo?(clave)
    prefijo = clave.to_s.split(".").first
    modulo = PERMISOS.find { |_, prefijos| prefijos.include?(prefijo) }&.first
    modulo.nil? || activo?(modulo)
  end

  # Al instalar no hay trabajo abierto que cuidar.
  def self.aplicar_giro!(giro)
    guardar!(GIROS.fetch(giro.to_s, OPCIONALES), comprobar: false)
  end

  # Enciende los de la lista y apaga el resto. Apagar algo con trabajo abierto se rechaza.
  def self.guardar!(lista, comprobar: true)
    nuevos = (Array(lista).map(&:to_s) & OPCIONALES)
    DEPENDE.each { |m, base| nuevos |= base if nuevos.include?(m) }
    (activos - nuevos).each { |m| comprobar_apagable!(m) } if comprobar
    Ajuste.guardar!(OPCIONALES.to_h { |m| [ "modulos.#{m}", nuevos.include?(m) ? "1" : "0" ] })
    Current.modulos = nil
  end

  def self.comprobar_apagable!(modulo)
    abierto = case modulo
    when "rutas" then Viaje.abiertos.exists?
    when "salidas" then Salida.abiertas.or(Salida.en_transito).exists?
    when "pedidos" then Pedido.abiertos.exists?
    when "etiquetas" then Produccion.abiertas.exists?
    when "conteos" then Conteo.abiertos.exists?
    when "almacenes" then Sucursal.activas.almacenes.exists?
    end
    raise ArgumentError, I18n.t("errores.modulo.con_trabajo_abierto", modulo: I18n.t("modulos.#{modulo}.nombre")) if abierto
  end
end

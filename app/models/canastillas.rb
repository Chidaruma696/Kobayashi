# Saldos de canastillas por tipo, por tres caminos: lo que debe cada cliente, lo que trae cada
# chofer (todo lo que lleva a bordo), y lo que debe cada ruta (la suma de sus clientes).
module Canastillas
  def self.saldo_cliente(cliente)
    MovimientoCanastilla.where(cliente: cliente).group(:tipo_canastilla_id).sum(:cantidad_cliente).reject { |_, v| v.zero? }
  end

  def self.saldo_chofer(chofer)
    MovimientoCanastilla.where(chofer: chofer).group(:tipo_canastilla_id).sum(:cantidad_chofer).reject { |_, v| v.zero? }
  end

  # { cliente_id => { tipo_id => saldo } } de todos los que deben algo.
  def self.saldos_clientes
    MovimientoCanastilla.where.not(cliente_id: nil).group(:cliente_id, :tipo_canastilla_id).sum(:cantidad_cliente)
                        .each_with_object({}) { |((c, t), v), h| (h[c] ||= {})[t] = v unless v.zero? }
  end

  # { ruta_id (nil = sin ruta) => { tipo_id => saldo } }: lo que deben entre todos los clientes de cada ruta.
  def self.saldos_rutas
    MovimientoCanastilla.joins(:cliente).group("clientes.ruta_id", :tipo_canastilla_id).sum(:cantidad_cliente)
                        .each_with_object({}) { |((r, t), v), h| (h[r] ||= {})[t] = v unless v.zero? }
  end

  def self.saldos_choferes
    MovimientoCanastilla.where.not(chofer_id: nil).group(:chofer_id, :tipo_canastilla_id).sum(:cantidad_chofer)
                        .each_with_object({}) { |((c, t), v), h| (h[c] ||= {})[t] = v unless v.zero? }
  end

  def self.mover!(tipo:, tipo_canastilla:, cantidad:, sucursal:, usuario:, cliente: nil, chofer: nil, viaje: nil, concepto: nil, fecha: Date.current)
    n = cantidad.to_i
    raise ArgumentError, I18n.t("errores.inventario.cantidad_cero") unless n.positive?
    cli, cho = case tipo
    when "carga" then [ 0, n ]
    when "entrega" then [ n, -n ]
    when "devolucion" then [ -n, chofer ? n : 0 ]
    when "descarga" then [ 0, -n ]
    else raise ArgumentError, I18n.t("errores.movimiento.tipo_desconocido", tipo: tipo)
    end
    MovimientoCanastilla.create!(tipo: tipo, tipo_canastilla: tipo_canastilla, cliente: cliente, chofer: chofer, viaje: viaje, sucursal: sucursal,
                                 cantidad_cliente: cliente ? cli : 0, cantidad_chofer: chofer ? cho : 0, fecha: fecha, concepto: concepto, usuario: usuario)
  end

  # Ajuste a mano, con motivo: cantidad con signo sobre el cliente o sobre el chofer.
  def self.ajustar!(tipo_canastilla:, cantidad:, motivo:, sucursal:, usuario:, cliente: nil, chofer: nil)
    raise ArgumentError, I18n.t("errores.escribe_motivo") if motivo.blank?
    raise ArgumentError, I18n.t("errores.canastillas.cliente_o_chofer") if cliente.nil? == chofer.nil?
    MovimientoCanastilla.create!(tipo: "ajuste", tipo_canastilla: tipo_canastilla, cliente: cliente, chofer: chofer, sucursal: sucursal,
                                 cantidad_cliente: cliente ? cantidad.to_i : 0, cantidad_chofer: chofer ? cantidad.to_i : 0,
                                 fecha: Date.current, concepto: motivo, usuario: usuario)
  end
end

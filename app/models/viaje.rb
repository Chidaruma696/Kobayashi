# La ruta de un día: sale un chofer con N repartos sellados, entrega parada por parada
# (escaneando lo que baja, rechazando lo que el cliente no quiso, cobrando de contado),
# y al volver la oficina liquida: efectivo cobrado − gastos = lo que debe entregar.
# Lo que falte se le carga.
class Viaje < ApplicationRecord
  ESTADOS = %w[armando en_ruta liquidado cancelado].freeze

  belongs_to :sucursal
  belongs_to :ruta
  belongs_to :chofer, class_name: "Usuario"
  belongs_to :usuario
  belongs_to :liquidado_por, class_name: "Usuario", optional: true
  has_many :salidas, dependent: :nullify
  has_many :gastos, class_name: "ViajeGasto", dependent: :destroy
  has_many :cargos, dependent: :restrict_with_error
  has_many :abonos, dependent: :restrict_with_error

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :fecha, presence: true

  scope :abiertos, -> { where(estado: %w[armando en_ruta]) }

  def armando? = estado == "armando"
  def en_ruta? = estado == "en_ruta"
  def liquidado? = estado == "liquidado"

  # Paradas en el orden de reparto de la ruta.
  def paradas
    salidas.includes(:cliente, :venta).sort_by { |s| [ s.cliente&.orden || 0, s.id ] }
  end

  def agregar!(salida)
    raise ArgumentError, "el viaje ya #{estado == 'en_ruta' ? 'salió' : "está #{estado}"}" unless armando?
    raise ArgumentError, "#{salida.folio} no es un reparto" unless salida.reparto?
    raise ArgumentError, "#{salida.folio} ya va en el viaje #{salida.viaje.folio}" if salida.viaje_id && salida.viaje_id != id
    raise ArgumentError, "#{salida.folio} está #{salida.estado}" unless salida.abierta?
    salida.update!(viaje: self)
  end

  def quitar!(salida)
    raise ArgumentError, "el viaje ya salió" unless armando?
    salida.update!(viaje: nil) if salida.viaje_id == id
  end

  # Sale el camión: cada reparto se envía (nace su nota por cobrar) y el viaje queda en ruta.
  def salir!(usuario:)
    raise ArgumentError, "el viaje está #{estado}" unless armando?
    raise ArgumentError, "el viaje no lleva repartos" if salidas.none?
    sin_sellar = salidas.reject(&:sellada?)
    raise ArgumentError, "faltan por sellar: #{sin_sellar.map(&:folio).join(', ')}" if sin_sellar.any?
    transaction do
      salidas.each { |s| s.enviar!(usuario: usuario) }
      update!(estado: "en_ruta", salido_en: Time.current)
    end
  end

  def ventas
    Venta.where(id: salidas.where.not(venta_id: nil).select(:venta_id))
  end

  def ventas_en_ruta
    ventas.where(en_ruta: true)
  end

  # { forma => centavos } de lo que el chofer cobró: pagos de notas y abonos a cuenta.
  def cobrado_centavos
    Pago.where(venta: ventas_en_ruta).group(:forma).sum(:monto_centavos)
        .merge(abonos.where(en_ruta: true).group(:forma).sum(:monto_centavos)) { |_, a, b| a + b }
  end

  def cambio_centavos
    ventas_en_ruta.sum(:cambio_centavos)
  end

  def credito_centavos
    ventas_en_ruta.where(estado: "a_credito").sum { |v| v.credito_centavos }
  end

  def gastos_centavos
    gastos.sum(:monto_centavos)
  end

  # Lo que el chofer debe entregar en efectivo: lo cobrado en efectivo menos cambio y gastos.
  def efectivo_por_entregar_centavos
    (cobrado_centavos["efectivo"] || 0) - cambio_centavos - gastos_centavos
  end

  def agregar_gasto!(concepto:, monto_centavos:, usuario:)
    raise ArgumentError, "el viaje está #{estado}" if liquidado? || estado == "cancelado"
    gastos.create!(concepto: concepto, monto_centavos: monto_centavos, usuario: usuario)
  end

  # Liquidar: las paradas que no se cerraron se dan por no entregadas, las ventas cobradas en
  # ruta entran a la caja abierta, los gastos salen de esa caja como retiro, y la diferencia
  # entre lo esperado y lo entregado se carga al chofer.
  def liquidar!(efectivo_entregado_centavos:, usuario:)
    raise ArgumentError, "el viaje está #{estado}" unless en_ruta?
    corte = Corte.abierto_en(sucursal) or raise ArgumentError, "no hay caja abierta en #{sucursal.nombre} para recibir el dinero"
    transaction do
      salidas.where(estado: "enviada").each { |s| s.cerrar_parada!(usuario: usuario, motivo_rechazo: "no se entregó (viaje #{folio} liquidado)") }
      esperado = efectivo_por_entregar_centavos
      ventas_en_ruta.find_each { |v| v.update!(en_ruta: false, corte: corte) }
      abonos.where(en_ruta: true).find_each { |a| a.update!(en_ruta: false, corte: corte) }
      gastos.each do |g|
        corte.retiros.create!(monto_centavos: g.monto_centavos, motivo: "Gasto de ruta #{folio}: #{g.concepto}", usuario: chofer, autorizado_por: usuario)
      end
      diferencia = efectivo_entregado_centavos.to_i - esperado
      update!(estado: "liquidado", liquidado_en: Time.current, liquidado_por: usuario, efectivo_esperado_centavos: esperado,
              efectivo_entregado_centavos: efectivo_entregado_centavos.to_i, diferencia_centavos: diferencia)
      if diferencia.negative?
        cargos.create!(usuario: chofer, sucursal: sucursal, monto_centavos: -diferencia,
                       detalle: "Viaje #{folio} (#{ruta}): esperaba #{Dinero.pesos(esperado)}, entregó #{Dinero.pesos(efectivo_entregado_centavos.to_i)}")
      end
    end
    self
  end

  def cancelar!
    raise ArgumentError, "solo se cancela antes de salir" unless armando?
    transaction do
      salidas.update_all(viaje_id: nil)
      update!(estado: "cancelado")
    end
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "V") if sucursal
  end
end

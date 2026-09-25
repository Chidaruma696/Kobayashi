# Corte de caja: abre con fondo, acumula lo que pasa por la gaveta y cierra contando.
class Corte < ApplicationRecord
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :cerrado_por, class_name: "Usuario", optional: true
  has_many :ventas, dependent: :restrict_with_error
  has_many :retiros, dependent: :restrict_with_error
  has_many :devoluciones, dependent: :restrict_with_error
  has_many :abonos, dependent: :restrict_with_error

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: { scope: :sucursal_id }
  validates :estado, inclusion: { in: %w[abierto cerrado] }
  validates :fondo_centavos, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :abiertos, -> { where(estado: "abierto") }

  def abierto? = estado == "abierto"

  def self.abierto_en(sucursal)
    abiertos.find_by(sucursal: sucursal)
  end

  # Un corte abierto por sucursal.
  def self.abrir!(sucursal:, usuario:, fondo_centavos:)
    raise ArgumentError, I18n.t("errores.corte.sin_caja_en_almacen", sucursal: sucursal.nombre) unless sucursal.caja?
    raise ArgumentError, I18n.t("errores.corte.ya_abierto", sucursal: sucursal.nombre) if abierto_en(sucursal)
    create!(sucursal: sucursal, usuario: usuario, fondo_centavos: fondo_centavos, abierto_en: Time.current)
  end

  # Ventas cuyo dinero ya entró (cobradas o luego devueltas); las notas por cobrar no cuentan.
  def ventas_cobradas
    ventas.where(en_ruta: false).where.not(estado: "por_cobrar")
  end

  # Efectivo que entró por ventas: lo pagado en efectivo menos el cambio devuelto.
  def efectivo_ventas_centavos
    Pago.where(venta: ventas_cobradas, forma: "efectivo").sum(:monto_centavos) - ventas_cobradas.sum(:cambio_centavos)
  end

  def total_ventas_centavos
    ventas_cobradas.sum(:total_centavos)
  end

  def devoluciones_centavos
    devoluciones.sum(:total_centavos)
  end

  def retiros_centavos
    retiros.sum(:monto_centavos)
  end

  # Lo que debe haber en la gaveta ahora mismo.
  def abonos_efectivo_centavos
    abonos.where(forma: "efectivo").sum(:monto_centavos)
  end

  def efectivo_esperado_centavos
    fondo_centavos + efectivo_ventas_centavos + abonos_efectivo_centavos - devoluciones_centavos - retiros_centavos
  end

  def excede_limite?
    efectivo_esperado_centavos > sucursal.limite_efectivo_centavos
  end

  def retirar!(monto_centavos:, motivo:, usuario:, autorizado_por: nil)
    raise ArgumentError, I18n.t("errores.corte.cerrado") unless abierto?
    raise ArgumentError, I18n.t("errores.hace_falta_motivo") if motivo.blank?
    monto = monto_centavos.to_i
    raise ArgumentError, I18n.t("errores.corte.sin_efectivo", monto: Dinero.pesos(efectivo_esperado_centavos)) if monto > efectivo_esperado_centavos
    retiros.create!(monto_centavos: monto, motivo: motivo, usuario: usuario, autorizado_por: autorizado_por)
  end

  def cerrar!(contado_centavos:, usuario:)
    raise ArgumentError, I18n.t("errores.corte.ya_cerrado") unless abierto?
    esperado = efectivo_esperado_centavos
    update!(estado: "cerrado", contado_centavos: contado_centavos.to_i, esperado_centavos: esperado,
            diferencia_centavos: contado_centavos.to_i - esperado, cerrado_en: Time.current, cerrado_por: usuario)
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "C") if sucursal
  end
end

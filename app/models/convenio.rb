# Convenio de precio con un cliente: precio fijo por kilo en ciertas líneas de producto (por
# ejemplo el pollo rosticero), hasta un tope SEMANAL de cajas que se acumula entre todas sus
# notas de la semana. Lo que cabe en el tope va a precio convenio; el excedente, a precio de
# lista. Los kilos se reparten en proporción a las cajas de cada renglón.
class Convenio < ApplicationRecord
  belongs_to :cliente
  has_many :venta_lineas, dependent: :restrict_with_error

  validates :lineas, presence: true
  validates :tope_cajas, numericality: { greater_than_or_equal_to: 0 }
  validates :precio_centavos, numericality: { only_integer: true, greater_than: 0 }
  validates :cliente_id, uniqueness: { conditions: -> { where(activo: true) }, message: ->(*) { I18n.t("errores.convenio.ya_activo") } }, if: :activo

  scope :activos, -> { where(activo: true) }

  def lineas_lista
    lineas.to_s.split(",").map { |l| l.strip.downcase }.reject(&:blank?)
  end

  def aplica?(producto)
    return false unless producto.kg? && producto.linea.present?
    return false if excluir.present? && producto.nombre.downcase.include?(excluir.downcase)
    lineas_lista.include?(producto.linea.downcase)
  end

  def precio
    precio_centavos && precio_centavos / 100.0
  end

  def precio=(pesos)
    self.precio_centavos = Dinero.centavos(pesos)
  end

  # Cajas del convenio ya usadas en la semana de `fecha` (notas vivas, no devueltas).
  def cajas_usadas(fecha)
    venta_lineas.joins(:venta).where(ventas: { fecha_negocio: fecha.beginning_of_week..fecha.end_of_week }).where.not(ventas: { estado: "devuelta" }).sum(:convenio_cajas)
  end

  # Re-precia las líneas preparadas de una nota (hashes de Caja.preparar_linea con :cajas).
  # Devuelve las mismas líneas, con importe, precio, convenio y convenio_cajas ajustados.
  def aplicar(lineas, fecha)
    restante = BigDecimal(tope_cajas.to_s) - cajas_usadas(fecha)
    lineas.map do |l|
      next l unless aplica?(l[:producto]) && l[:cajas].to_d.positive? && restante.positive?
      cajas = l[:cajas].to_d
      conv_cajas = [ cajas, restante ].min
      restante -= conv_cajas
      kg = l[:cantidad]
      conv_kg = (kg * conv_cajas / cajas).round(3)
      importe = Dinero.importe(conv_kg, precio_centavos) + Dinero.importe(kg - conv_kg, l[:precio_centavos])
      l.merge(importe_centavos: importe, precio_centavos: (importe / kg).round.to_i, convenio: self, convenio_cajas: conv_cajas, promocion: nil)
    end
  end

  def to_s
    "#{Dinero.pesos(precio_centavos)}/kg en #{lineas} hasta #{tope_cajas.to_s('F')} cajas por semana"
  end
end

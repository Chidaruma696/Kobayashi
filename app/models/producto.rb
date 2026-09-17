class Producto < ApplicationRecord
  UNIDADES = %w[kg pieza].freeze
  PLU_INICIAL = 90_000

  has_many :codigos_barras, class_name: "CodigoBarras", dependent: :destroy
  has_many :existencias, dependent: :restrict_with_error
  has_many :etiquetas, dependent: :restrict_with_error
  has_many :pedido_lineas, dependent: :restrict_with_error

  before_validation :asignar_plu, on: :create

  validates :clave, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :nombre, presence: true
  validates :unidad, inclusion: { in: UNIDADES }
  validates :precio_centavos, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :plu, numericality: { only_integer: true, in: 1..99_999 }, uniqueness: true
  validates :peso_fijo, numericality: { greater_than: 0 }, allow_nil: true

  scope :activos, -> { where(activo: true) }

  def kg?
    unidad == "kg"
  end

  def precio
    BigDecimal(precio_centavos) / 100
  end

  def precio=(pesos)
    self.precio_centavos = (BigDecimal(pesos.to_s) * 100).round.to_i
  end

  # Decimales con los que se captura la cantidad: kilos a 3, piezas enteras.
  def decimales
    kg? ? 3 : 0
  end

  def to_s
    nombre
  end

  private

  def asignar_plu
    return if plu.present?
    self.plu = [ Producto.maximum(:plu).to_i + 1, PLU_INICIAL ].max
  end
end

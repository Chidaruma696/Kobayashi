class Sucursal < ApplicationRecord
  # matriz: donde se produce, se etiqueta y de donde sale todo. tienda: vende, todo con etiqueta.
  # almacen: frigorífico o bodega externa donde la mercancía solo se guarda a granel: sin caja, sin
  # etiquetas, sin conteos; entra y sale por traspasos a granel, y de ahí solo va a la matriz.
  TIPOS = %w[matriz tienda almacen].freeze

  has_many :usuarios, dependent: :restrict_with_error
  has_many :folios, dependent: :destroy
  has_many :existencias, dependent: :restrict_with_error
  has_many :etiquetas, dependent: :restrict_with_error
  has_many :cortes, dependent: :restrict_with_error
  has_many :ventas, dependent: :restrict_with_error
  has_many :salidas_enviadas, class_name: "Salida", foreign_key: :sucursal_origen_id, dependent: :restrict_with_error, inverse_of: :sucursal_origen
  has_many :salidas_recibidas, class_name: "Salida", foreign_key: :sucursal_destino_id, dependent: :restrict_with_error, inverse_of: :sucursal_destino

  validates :limite_efectivo_centavos, numericality: { only_integer: true, greater_than: 0 }

  validates :codigo, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :nombre, presence: true
  validates :tipo, inclusion: { in: TIPOS }

  scope :activas, -> { where(activa: true) }

  def self.matriz
    find_by(tipo: "matriz")
  end

  def matriz?
    tipo == "matriz"
  end

  def almacen? = tipo == "almacen"

  # Dónde la etiqueta significa algo (se genera, se cuenta, viaja) y dónde hay caja.
  def etiquetas? = !almacen?
  def caja? = !almacen?

  scope :con_caja, -> { where.not(tipo: "almacen") }
  scope :almacenes, -> { where(tipo: "almacen") }

  def limite_efectivo
    BigDecimal(limite_efectivo_centavos) / 100
  end

  def to_s
    nombre
  end
end

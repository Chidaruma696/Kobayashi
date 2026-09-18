class Venta < ApplicationRecord
  belongs_to :sucursal
  belongs_to :corte
  belongs_to :usuario
  belongs_to :cliente, optional: true
  has_many :lineas, class_name: "VentaLinea", dependent: :restrict_with_error, inverse_of: :venta
  has_many :pagos, dependent: :restrict_with_error
  has_many :devoluciones, dependent: :restrict_with_error

  validates :folio, :codigo, :clave, presence: true, uniqueness: true
  validates :estado, inclusion: { in: %w[por_cobrar cobrada_en_ruta cobrada devuelta] }
  validates :total_centavos, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recientes, -> { order(created_at: :desc) }

  def cobrada? = estado == "cobrada"
  def por_cobrar? = estado == "por_cobrar"
  def cobrada_en_ruta? = estado == "cobrada_en_ruta"

  # Lo que queda por pagar de la nota: el total menos lo que se rechazó o devolvió.
  def saldo_centavos
    total_centavos - total_devuelto_centavos
  end

  # El ticket lleva su propio EAN-13 (prefijo 09 + sucursal + secuencia) para devoluciones.
  def self.buscar(texto)
    find_by(codigo: Barcode.variantes(texto)) || find_by(folio: texto.to_s.strip.upcase)
  end

  def total_devuelto_centavos
    devoluciones.sum(:total_centavos)
  end

  def to_s
    folio
  end
end

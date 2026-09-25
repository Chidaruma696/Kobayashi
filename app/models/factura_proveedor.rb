# La factura del proveedor: lo único que crea deuda, con renglones que son el único sitio donde
# vive el precio de compra. El monto se deriva de los renglones; sin renglones (flete, hielo) se
# acepta el monto tecleado. Se liga a las recepciones después, y facturar nunca toca el inventario.
class FacturaProveedor < ApplicationRecord
  self.table_name = "facturas_proveedor"

  belongs_to :proveedor
  belongs_to :sucursal
  belongs_to :usuario
  has_many :lineas, class_name: "FacturaProveedorLinea", dependent: :destroy, inverse_of: :factura
  has_many :recepciones, dependent: :nullify
  has_many :pagos, class_name: "PagoProveedor", dependent: :restrict_with_error
  has_many :movimientos, class_name: "MovimientoProveedor", dependent: :restrict_with_error

  validates :folio, presence: true, uniqueness: { scope: :proveedor_id }
  validates :fecha, presence: true
  validates :monto_centavos, numericality: { only_integer: true, greater_than: 0 }
  validates :estado, inclusion: { in: %w[abierta cancelada] }

  scope :abiertas, -> { where(estado: "abierta") }

  def abierta? = estado == "abierta"
  def cancelada? = estado == "cancelada"
  def pagado_centavos = pagos.vigentes.sum(:monto_centavos)
  def resta_centavos = monto_centavos - pagado_centavos
  def pagada? = resta_centavos <= 0
  def vencida? = abierta? && !pagada? && vence.present? && vence < Date.current

  def to_s = folio
end

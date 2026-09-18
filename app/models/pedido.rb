class Pedido < ApplicationRecord
  ESTADOS = %w[solicitado surtiendo cerrado cancelado].freeze

  belongs_to :sucursal_origen, class_name: "Sucursal"
  belongs_to :sucursal_destino, class_name: "Sucursal", optional: true
  belongs_to :cliente, optional: true
  belongs_to :usuario
  has_many :lineas, class_name: "PedidoLinea", dependent: :destroy, inverse_of: :pedido
  has_many :producciones, dependent: :restrict_with_error
  accepts_nested_attributes_for :lineas, reject_if: ->(a) { a[:producto_id].blank? && a[:cantidad].blank? }

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: true
  validates :estado, inclusion: { in: ESTADOS }
  validate :un_solo_destino
  validate :con_lineas, on: :create

  scope :abiertos, -> { where(estado: %w[solicitado surtiendo]) }
  scope :recientes, -> { order(created_at: :desc) }

  def abierto? = %w[solicitado surtiendo].include?(estado)

  def destino
    cliente || sucursal_destino
  end

  def linea_de(producto)
    lineas.find { |l| l.producto_id == producto.id }
  end

  # Al ligar la primera etiqueta el pedido pasa a surtiendo.
  def surtiendo!
    update!(estado: "surtiendo") if estado == "solicitado"
  end

  # Todos los renglones resueltos (surtidos o apartados) y nada pendiente.
  def resuelto?
    lineas.none?(&:pendiente?)
  end

  def cancelar!
    raise ArgumentError, "solo se cancela un pedido abierto" unless abierto?
    raise ArgumentError, "ya tiene etiquetas surtidas; no se puede cancelar" if lineas.any? { |l| l.cantidad_surtida.positive? }
    update!(estado: "cancelado")
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal_origen, "P") if sucursal_origen
  end

  def un_solo_destino
    if cliente.nil? && sucursal_destino.nil? || cliente && sucursal_destino
      errors.add(:base, "el pedido va a una tienda o a un cliente, uno de los dos")
    end
    errors.add(:sucursal_destino, "no puede ser la misma que surte") if sucursal_destino && sucursal_origen_id == sucursal_destino_id
  end

  def con_lineas
    errors.add(:lineas, "el pedido necesita al menos un renglón") if lineas.empty?
  end
end

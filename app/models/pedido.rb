class Pedido < ApplicationRecord
  ESTADOS = %w[solicitado surtiendo cerrado cancelado].freeze

  belongs_to :sucursal_origen, class_name: "Sucursal"
  belongs_to :sucursal_destino, class_name: "Sucursal", optional: true
  belongs_to :cliente, optional: true
  belongs_to :usuario
  has_many :lineas, class_name: "PedidoLinea", dependent: :destroy, inverse_of: :pedido
  accepts_nested_attributes_for :lineas, reject_if: ->(a) { a[:producto_id].blank? && a[:cantidad].blank? }

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: { scope: :sucursal_origen_id }
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
    raise ArgumentError, I18n.t("errores.pedido.solo_abierto") unless abierto?
    raise ArgumentError, I18n.t("errores.pedido.ya_surtido") if lineas.any? { |l| l.cantidad_surtida.positive? }
    update!(estado: "cancelado")
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal_origen, "pedido") if sucursal_origen
  end

  def un_solo_destino
    if cliente.nil? && sucursal_destino.nil? || cliente && sucursal_destino
      errors.add(:base, I18n.t("errores.pedido.un_destino"))
    end
    errors.add(:sucursal_destino, I18n.t("errores.pedido.mismo_origen")) if sucursal_destino && sucursal_origen_id == sucursal_destino_id
  end

  def con_lineas
    errors.add(:lineas, I18n.t("errores.pedido.sin_renglones")) if lineas.empty?
  end
end

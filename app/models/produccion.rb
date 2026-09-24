# Entra un producto en una cantidad y salen las etiquetas que se crean bajo la producción.
# Nunca sale más de lo que entró; la diferencia al cerrar es la merma.
class Produccion < ApplicationRecord
  self.table_name = "producciones"

  belongs_to :sucursal
  belongs_to :pedido, optional: true
  belongs_to :producto
  belongs_to :usuario
  belongs_to :autorizado_por, class_name: "Usuario", optional: true
  has_many :etiquetas, dependent: :restrict_with_error

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: true
  validates :cantidad, numericality: { greater_than: 0 }
  validates :estado, inclusion: { in: %w[abierta cerrada] }
  validate :pedido_o_autorizacion

  scope :abiertas, -> { where(estado: "abierta") }

  def abierta? = estado == "abierta"

  # Abre la producción consumiendo la entrada de la existencia de la sucursal.
  def self.abrir!(sucursal:, producto:, cantidad:, usuario:, pedido: nil, autorizado_por: nil, justificacion: nil)
    transaction do
      p = create!(sucursal: sucursal, producto: producto, cantidad: cantidad, usuario: usuario,
                  pedido: pedido, autorizado_por: autorizado_por, justificacion: justificacion)
      Inventario.mover!(sucursal: sucursal, producto: producto, tipo: "consumo", cantidad: cantidad,
                        usuario: usuario, referencia: p, motivo: "Producción #{p.folio}")
      p
    end
  end

  # { producto => cantidad } de lo etiquetado hasta ahora.
  def salidas
    etiquetas.vivas.hojas.includes(:producto).group_by(&:producto).transform_values { |es| es.sum(&:cantidad) }
  end

  def total_salidas
    etiquetas.vivas.hojas.sum(:cantidad)
  end

  def disponible
    cantidad - total_salidas
  end

  # ¿Cabe una salida más de `extra`? Nunca sale más de lo que entró.
  def cabe?(extra)
    abierta? && total_salidas + extra <= cantidad
  end

  # Cierra: las salidas entran a la existencia y la merma queda registrada en la producción.
  def cerrar!(usuario:)
    raise ArgumentError, "la producción ya está cerrada" unless abierta?
    transaction do
      salidas.each do |producto, cant|
        Inventario.mover!(sucursal: sucursal, producto: producto, tipo: "produccion", cantidad: cant,
                          usuario: usuario, referencia: self, motivo: "Producción #{folio}")
      end
      update!(estado: "cerrada", merma: disponible)
    end
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "PR") if sucursal
  end

  def pedido_o_autorizacion
    return if pedido.present?
    errors.add(:base, "sin pedido hace falta el motivo") if justificacion.blank?
  end
end

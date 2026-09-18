class Ruta < ApplicationRecord
  belongs_to :chofer, class_name: "Usuario", optional: true
  has_many :clientes, dependent: :restrict_with_error
  has_many :salidas, dependent: :restrict_with_error
  has_many :viajes, dependent: :restrict_with_error
  has_many :zonas, dependent: :destroy
  accepts_nested_attributes_for :zonas, allow_destroy: true, reject_if: ->(a) { a[:nombre].blank? }

  # Clientes activos en el orden de reparto: zona (por su orden) y luego el orden del cliente.
  def clientes_en_orden
    clientes.activos.includes(:zona).sort_by(&:orden_reparto)
  end

  validates :nombre, presence: true, uniqueness: true

  scope :activas, -> { where(activa: true) }

  def to_s
    nombre
  end
end

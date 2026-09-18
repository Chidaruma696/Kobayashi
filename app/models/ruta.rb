class Ruta < ApplicationRecord
  belongs_to :chofer, class_name: "Usuario", optional: true
  has_many :clientes, dependent: :restrict_with_error
  has_many :salidas, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: true

  scope :activas, -> { where(activa: true) }

  def to_s
    nombre
  end
end

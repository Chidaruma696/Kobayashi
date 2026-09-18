class Cliente < ApplicationRecord
  belongs_to :ruta, optional: true
  has_many :pedidos, dependent: :restrict_with_error
  has_many :salidas, dependent: :restrict_with_error
  has_many :ventas, dependent: :restrict_with_error

  validates :nombre, presence: true

  scope :activos, -> { where(activo: true) }

  def to_s
    nombre
  end
end

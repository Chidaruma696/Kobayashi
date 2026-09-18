class Zona < ApplicationRecord
  belongs_to :ruta
  has_many :clientes, dependent: :nullify

  validates :nombre, presence: true, uniqueness: { scope: :ruta_id }
  validates :orden, numericality: { only_integer: true }

  scope :activas, -> { where(activa: true) }
  scope :en_orden, -> { order(:orden, :nombre) }

  def to_s
    nombre
  end
end

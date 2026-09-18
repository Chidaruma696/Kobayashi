class TipoCanastilla < ApplicationRecord
  self.table_name = "tipos_canastilla"

  has_many :salida_canastillas, dependent: :restrict_with_error
  has_many :movimientos_canastillas, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: true

  scope :activos, -> { where(activo: true).order(:nombre) }

  def to_s
    color.present? ? "#{nombre} #{color}" : nombre
  end
end

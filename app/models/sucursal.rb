class Sucursal < ApplicationRecord
  TIPOS = %w[matriz tienda].freeze

  has_many :usuarios, dependent: :restrict_with_error
  has_many :folios, dependent: :destroy
  has_many :existencias, dependent: :restrict_with_error
  has_many :etiquetas, dependent: :restrict_with_error
  has_many :cortes, dependent: :restrict_with_error
  has_many :ventas, dependent: :restrict_with_error

  validates :limite_efectivo_centavos, numericality: { only_integer: true, greater_than: 0 }

  validates :codigo, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :nombre, presence: true
  validates :tipo, inclusion: { in: TIPOS }

  scope :activas, -> { where(activa: true) }

  def self.matriz
    find_by(tipo: "matriz")
  end

  def matriz?
    tipo == "matriz"
  end

  def to_s
    nombre
  end
end

class Sucursal < ApplicationRecord
  TIPOS = %w[matriz tienda].freeze

  has_many :usuarios, dependent: :restrict_with_error
  has_many :folios, dependent: :destroy

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

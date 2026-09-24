class Usuario < ApplicationRecord
  belongs_to :rol
  belongs_to :sucursal

  has_secure_password

  validates :nombre, presence: true
  validates :usuario, presence: true, uniqueness: true,
                      format: { with: /\A[a-z0-9._-]+\z/, message: "solo minúsculas, números, punto y guion" }

  has_many :cargos, dependent: :restrict_with_error

  scope :activos, -> { where(activo: true) }

  def puede?(clave)
    activo && rol.permite?(clave)
  end


  def to_s
    nombre
  end
end

class Usuario < ApplicationRecord
  belongs_to :rol
  belongs_to :sucursal

  has_secure_password
  # PIN corto para autorizar en caja (bajar un precio, un retiro…) sin cerrar la sesión del cajero.
  has_secure_password :pin, validations: false

  validates :nombre, presence: true
  validates :usuario, presence: true, uniqueness: true,
                      format: { with: /\A[a-z0-9._-]+\z/, message: "solo minúsculas, números, punto y guion" }
  validates :pin, length: { in: 4..8 }, format: { with: /\A\d+\z/, message: "solo dígitos" }, allow_nil: true

  has_many :cargos, dependent: :restrict_with_error

  scope :activos, -> { where(activo: true) }

  def puede?(clave)
    activo && rol.permite?(clave)
  end

  # Quién autoriza: un usuario activo con el permiso cuyo PIN coincida. nil si nadie.
  def self.autorizador(clave, pin)
    return nil if pin.blank?
    activos.includes(:rol).find { |u| u.pin_digest.present? && u.puede?(clave) && u.authenticate_pin(pin) }
  end

  def to_s
    nombre
  end
end

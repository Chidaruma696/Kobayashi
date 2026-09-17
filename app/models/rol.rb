class Rol < ApplicationRecord
  has_many :usuarios, dependent: :restrict_with_error

  validates :nombre, presence: true, uniqueness: true
  validate :permisos_conocidos

  def permite?(clave)
    Permiso.cubre?(permisos, clave)
  end

  def to_s
    nombre
  end

  private

  def permisos_conocidos
    return errors.add(:permisos, "debe ser una lista") unless permisos.is_a?(Array)
    desconocidos = permisos.reject { |c| Permiso.valida?(c) }
    errors.add(:permisos, "desconocidos: #{desconocidos.join(', ')}") if desconocidos.any?
  end
end

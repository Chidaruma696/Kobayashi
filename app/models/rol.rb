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
    return errors.add(:permisos, I18n.t("errores.rol.lista")) unless permisos.is_a?(Array)
    desconocidos = permisos.reject { |c| Permiso.valida?(c) }
    errors.add(:permisos, I18n.t("errores.rol.desconocidos", claves: desconocidos.join(", "))) if desconocidos.any?
  end
end

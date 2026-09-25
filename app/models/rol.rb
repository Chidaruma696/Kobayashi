class Rol < ApplicationRecord
  has_many :usuarios, dependent: :restrict_with_error

  # Roles con los que arranca el sistema; el administrador lo puede todo. Se pueden editar después.
  BASE = {
    "administrador" => [ "*" ],
    "cajero" => [ "caja.vender", "caja.abrir", "caja.retirar", "caja.devolver", "inventario.ver", "pedidos.solicitar", "salidas.recibir", "salidas.surtir", "salidas.verificar" ],
    "etiquetador" => [ "etiquetas.crear", "produccion.abrir", "pedidos.surtir", "inventario.ver", "salidas.surtir", "salidas.recibir" ],
    "chofer" => [ "rutas.repartir", "pedidos.solicitar" ],
    "supervisor" => [ "caja.*", "inventario.*", "compras.*", "etiquetas.*", "pedidos.*", "produccion.*", "salidas.*", "rutas.*", "cobranza.*", "canastillas.*", "conteos.*", "reportes.ver", "revisiones.resolver" ]
  }.freeze

  validates :nombre, presence: true, uniqueness: true
  validate :permisos_conocidos

  def self.base!
    BASE.each { |nombre, permisos| find_or_initialize_by(nombre: nombre).update!(permisos: permisos) }
  end

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

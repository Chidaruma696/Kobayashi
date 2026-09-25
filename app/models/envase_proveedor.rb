# El libro de envases del proveedor (canastilla, tarima, tote): lo que nos deja y le debemos, lo
# que le devolvemos, y los ajustes. Solo-inserción; el saldo es Σ cantidad × signo por envase.
class EnvaseProveedor < ApplicationRecord
  self.table_name = "envases_proveedor"
  ENVASES = %w[canastilla tarima tote].freeze

  belongs_to :proveedor
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :recepcion, optional: true

  validates :envase, inclusion: { in: ENVASES }
  validates :tipo, inclusion: { in: %w[entrada devolucion ajuste] }
  validates :cantidad, numericality: { only_integer: true, greater_than: 0 }
  validates :signo, inclusion: { in: [ 1, -1 ] }

  before_update { raise ActiveRecord::ReadOnlyRecord, "el libro de envases no se edita" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "el libro de envases no se borra" }
end

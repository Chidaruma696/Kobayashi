# Mínimo y máximo de un producto en una sucursal. Por debajo del mínimo, el pedido sugerido pide
# lo que falta para llegar al máximo (o al mínimo, si no hay máximo).
class MinimoSucursal < ApplicationRecord
  self.table_name = "minimos_sucursal"

  belongs_to :producto
  belongs_to :sucursal

  validates :minimo, numericality: { greater_than_or_equal_to: 0 }
  validates :maximo, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :sucursal_id, uniqueness: { scope: :producto_id }
  validate { errors.add(:maximo, I18n.t("errores.minimo.maximo_menor")) if maximo && maximo < minimo }

  def tope = [ minimo, maximo ].compact.max
end

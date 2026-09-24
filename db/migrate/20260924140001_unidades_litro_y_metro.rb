# Además de kilo y pieza, litro y metro: fraccionables a tres decimales, como el kilo.
class UnidadesLitroYMetro < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :productos, name: "productos_unidad"
    add_check_constraint :productos, "unidad IN ('kg', 'pieza', 'litro', 'metro')", name: "productos_unidad"
  end

  def down
    remove_check_constraint :productos, name: "productos_unidad"
    add_check_constraint :productos, "unidad IN ('kg', 'pieza')", name: "productos_unidad"
  end
end

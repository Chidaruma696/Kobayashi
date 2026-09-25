# Producción con rendimiento: el producto que entra dice cuánta merma se espera de él, y la
# producción se queda con el costo de lo que entró (último precio de compra) para repartirlo.
class RendimientoProduccion < ActiveRecord::Migration[8.1]
  def change
    add_column :productos, :merma_esperada, :decimal, precision: 5, scale: 2
    add_column :producciones, :costo_centavos, :integer
  end
end

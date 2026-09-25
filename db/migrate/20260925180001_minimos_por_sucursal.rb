# Mínimo y máximo de un producto en una sucursal: cuando la existencia baja del mínimo, el pedido
# nuevo trae lo que falta para llegar al máximo.
class MinimosPorSucursal < ActiveRecord::Migration[8.1]
  def change
    create_table :minimos_sucursal do |t|
      t.references :producto, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.decimal :minimo, precision: 12, scale: 3, null: false, default: 0
      t.decimal :maximo, precision: 12, scale: 3
      t.timestamps
    end
    add_index :minimos_sucursal, [ :producto_id, :sucursal_id ], unique: true
  end
end

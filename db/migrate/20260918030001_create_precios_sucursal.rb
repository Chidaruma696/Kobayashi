class CreatePreciosSucursal < ActiveRecord::Migration[8.1]
  def change
    # Precio de un producto en una sucursal concreta. Si no hay fila, rige el precio general.
    create_table :precios_sucursal do |t|
      t.references :producto, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.integer :precio_centavos, null: false

      t.timestamps
    end
    add_index :precios_sucursal, [ :producto_id, :sucursal_id ], unique: true
    add_check_constraint :precios_sucursal, "precio_centavos >= 0", name: "precios_sucursal_no_negativo"
  end
end

class CreatePromociones < ActiveRecord::Migration[8.1]
  def change
    # Reglas de precio: precio especial, porcentaje de descuento, o precio a partir de una cantidad
    # (mayoreo). Por producto, para una sucursal o para todas, con vigencia opcional.
    create_table :promociones do |t|
      t.string :nombre, null: false
      t.references :producto, null: false, foreign_key: true
      t.references :sucursal, foreign_key: true
      t.string :tipo, null: false
      t.integer :precio_centavos
      t.decimal :porcentaje, precision: 5, scale: 2
      t.decimal :cantidad_minima, precision: 12, scale: 3, null: false, default: 0
      t.date :desde
      t.date :hasta
      t.boolean :activa, null: false, default: true

      t.timestamps
    end
    add_index :promociones, [ :producto_id, :activa ]
    add_check_constraint :promociones, "tipo IN ('precio', 'porcentaje', 'por_cantidad')", name: "promociones_tipo"
    add_reference :venta_lineas, :promocion, foreign_key: { to_table: :promociones }
  end
end

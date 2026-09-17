class CreateMovimientos < ActiveRecord::Migration[8.1]
  def change
    # Kardex: la fuente de verdad del inventario. Solo se inserta; nunca se edita ni se borra.
    create_table :movimientos do |t|
      t.references :sucursal, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.string :tipo, null: false
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      # Existencia que quedó después del movimiento, para leer el kardex sin sumar.
      t.decimal :saldo, precision: 12, scale: 3, null: false
      t.references :etiqueta, foreign_key: true
      t.references :referencia, polymorphic: true
      t.references :usuario, null: false, foreign_key: true
      t.string :motivo
      t.date :fecha_negocio, null: false

      t.timestamps
    end
    add_index :movimientos, [ :sucursal_id, :producto_id, :created_at ]
    add_index :movimientos, [ :sucursal_id, :fecha_negocio ]
    add_check_constraint :movimientos, "cantidad > 0", name: "movimientos_cantidad_positiva"
    add_check_constraint :movimientos,
      "tipo IN ('entrada', 'produccion', 'recepcion', 'devolucion_cliente', 'ajuste_entrada', 'venta', 'salida', 'merma', 'ajuste_salida')",
      name: "movimientos_tipo"
  end
end

class CreatePedidos < ActiveRecord::Migration[8.1]
  def change
    # Pedido de abasto: una tienda (o ruta, más adelante) le pide a la sucursal que surte.
    create_table :pedidos do |t|
      t.string :folio, null: false
      t.references :sucursal_origen, null: false, foreign_key: { to_table: :sucursales }
      t.references :sucursal_destino, null: false, foreign_key: { to_table: :sucursales }
      t.references :usuario, null: false, foreign_key: true
      t.string :estado, null: false, default: "solicitado"
      t.text :notas

      t.timestamps
    end
    add_index :pedidos, :folio, unique: true
    add_index :pedidos, [ :sucursal_origen_id, :estado ]
    add_check_constraint :pedidos, "estado IN ('solicitado', 'surtiendo', 'cerrado', 'cancelado')", name: "pedidos_estado"

    create_table :pedido_lineas do |t|
      t.references :pedido, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.string :estado, null: false, default: "pendiente"
      t.string :motivo

      t.timestamps
    end
    add_check_constraint :pedido_lineas, "cantidad > 0", name: "pedido_lineas_cantidad"
    add_check_constraint :pedido_lineas, "estado IN ('pendiente', 'surtido', 'no_surtir')", name: "pedido_lineas_estado"
  end
end

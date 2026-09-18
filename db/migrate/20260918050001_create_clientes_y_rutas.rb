class CreateClientesYRutas < ActiveRecord::Migration[8.1]
  def change
    create_table :rutas do |t|
      t.string :nombre, null: false
      t.references :chofer, foreign_key: { to_table: :usuarios }
      t.boolean :activa, null: false, default: true

      t.timestamps
    end
    add_index :rutas, :nombre, unique: true

    # Cliente de reparto: se le surte como a una tienda, pero paga de contado contra entrega.
    create_table :clientes do |t|
      t.string :nombre, null: false
      t.string :telefono
      t.string :direccion
      t.references :ruta, foreign_key: true
      t.integer :orden, null: false, default: 0
      t.boolean :activo, null: false, default: true
      t.text :notas

      t.timestamps
    end
    add_index :clientes, :nombre

    # Un pedido o una salida van a una tienda o a un cliente.
    change_column_null :pedidos, :sucursal_destino_id, true
    add_reference :pedidos, :cliente, foreign_key: true
    change_column_null :salidas, :sucursal_destino_id, true
    add_reference :salidas, :cliente, foreign_key: true
    add_reference :salidas, :ruta, foreign_key: true
    add_reference :salidas, :venta, foreign_key: true
    remove_check_constraint :salidas, name: "salidas_tipo"
    add_check_constraint :salidas, "tipo IN ('traspaso', 'devolucion', 'reparto')", name: "salidas_tipo"
    remove_check_constraint :salidas, name: "salidas_estado"
    add_check_constraint :salidas, "estado IN ('preparando', 'sellada', 'enviada', 'recibida', 'entregada', 'cancelada')", name: "salidas_estado"

    add_reference :ventas, :cliente, foreign_key: true
    remove_check_constraint :ventas, name: "ventas_estado"
    add_check_constraint :ventas, "estado IN ('por_cobrar', 'cobrada', 'devuelta')", name: "ventas_estado"
  end
end

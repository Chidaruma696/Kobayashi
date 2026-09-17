class CreateProducciones < ActiveRecord::Migration[8.1]
  def change
    # Entra un producto (se consume al abrir) y salen las etiquetas que se crean bajo la producción.
    create_table :producciones do |t|
      t.string :folio, null: false
      t.references :sucursal, null: false, foreign_key: true
      t.references :pedido, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.decimal :merma, precision: 12, scale: 3
      t.string :estado, null: false, default: "abierta"
      t.references :usuario, null: false, foreign_key: true
      t.references :autorizado_por, foreign_key: { to_table: :usuarios }
      t.string :justificacion

      t.timestamps
    end
    add_index :producciones, :folio, unique: true
    add_check_constraint :producciones, "cantidad > 0", name: "producciones_cantidad"
    add_check_constraint :producciones, "estado IN ('abierta', 'cerrada')", name: "producciones_estado"
  end
end

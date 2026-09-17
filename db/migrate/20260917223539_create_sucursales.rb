class CreateSucursales < ActiveRecord::Migration[8.1]
  def change
    create_table :sucursales do |t|
      t.string :codigo, null: false
      t.string :nombre, null: false
      t.string :tipo, null: false, default: "tienda"
      t.boolean :activa, null: false, default: true

      t.timestamps
    end
    add_index :sucursales, :codigo, unique: true
    add_check_constraint :sucursales, "tipo IN ('matriz', 'tienda')", name: "sucursales_tipo"
  end
end

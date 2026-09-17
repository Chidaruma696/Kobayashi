class CreateExistencias < ActiveRecord::Migration[8.1]
  def change
    # Proyección del kardex: cuánto hay de cada producto en cada sucursal. Nunca se edita a mano.
    create_table :existencias do |t|
      t.references :sucursal, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false, default: 0

      t.timestamps
    end
    add_index :existencias, [ :sucursal_id, :producto_id ], unique: true
    add_check_constraint :existencias, "cantidad >= 0", name: "existencias_no_negativas"
  end
end

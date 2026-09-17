class CreateCodigosBarras < ActiveRecord::Migration[8.1]
  def change
    # Códigos del proveedor (EAN-13, UPC-A…) que identifican a un producto. Varios por producto.
    create_table :codigos_barras do |t|
      t.references :producto, null: false, foreign_key: true
      t.string :codigo, null: false

      t.timestamps
    end
    add_index :codigos_barras, :codigo, unique: true
  end
end

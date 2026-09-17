class CreateProductos < ActiveRecord::Migration[8.1]
  def change
    create_table :productos do |t|
      t.string :clave, null: false
      t.string :nombre, null: false
      t.string :linea
      t.string :unidad, null: false, default: "kg"
      # Dinero en centavos enteros; nunca flotantes.
      t.integer :precio_centavos, null: false, default: 0
      # PLU de la báscula y de las etiquetas de identidad (5 dígitos).
      t.integer :plu, null: false
      # Peso en kilos de una pieza, para productos por pieza que también se pesan (opcional).
      t.decimal :peso_fijo, precision: 10, scale: 3
      t.boolean :activo, null: false, default: true

      t.timestamps
    end
    add_index :productos, :clave, unique: true
    add_index :productos, :plu, unique: true
    add_check_constraint :productos, "unidad IN ('kg', 'pieza')", name: "productos_unidad"
    add_check_constraint :productos, "precio_centavos >= 0", name: "productos_precio_no_negativo"
    add_check_constraint :productos, "plu BETWEEN 1 AND 99999", name: "productos_plu_rango"
  end
end

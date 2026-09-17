class CreateEtiquetas < ActiveRecord::Migration[8.1]
  def change
    # Paquete, caja o tarima con barcode de identidad. Caja y tarima agrupan a sus hijas.
    create_table :etiquetas do |t|
      t.string :tipo, null: false
      t.string :codigo, null: false, limit: 13
      t.references :producto, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.references :padre, foreign_key: { to_table: :etiquetas }
      # Kilos o piezas del paquete; en cajas y tarimas, la suma de sus hijas (o el contenido directo).
      t.decimal :cantidad, precision: 12, scale: 3, null: false, default: 0
      t.string :estado, null: false, default: "viva"
      t.references :usuario, null: false, foreign_key: true
      t.string :motivo

      t.timestamps
    end
    add_index :etiquetas, :codigo, unique: true
    add_index :etiquetas, [ :sucursal_id, :estado, :tipo ]
    add_check_constraint :etiquetas, "tipo IN ('paquete', 'caja', 'tarima')", name: "etiquetas_tipo"
    add_check_constraint :etiquetas, "estado IN ('viva', 'vendida', 'baja')", name: "etiquetas_estado"
    add_check_constraint :etiquetas, "cantidad >= 0", name: "etiquetas_cantidad"
  end
end

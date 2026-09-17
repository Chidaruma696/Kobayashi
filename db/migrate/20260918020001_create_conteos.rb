class CreateConteos < ActiveRecord::Migration[8.1]
  def change
    # Conteo físico del supervisor: escanea todo lo que hay, el sistema compara y lo que falta se
    # le carga al responsable. El conteo manda: al cerrar, el inventario se ajusta a lo contado.
    create_table :conteos do |t|
      t.string :folio, null: false
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :responsable, null: false, foreign_key: { to_table: :usuarios }
      t.string :estado, null: false, default: "abierto"
      t.integer :faltante_centavos
      t.integer :sobrante_centavos
      t.datetime :cerrado_en
      t.text :notas

      t.timestamps
    end
    add_index :conteos, :folio, unique: true
    add_index :conteos, [ :sucursal_id, :estado ]
    add_check_constraint :conteos, "estado IN ('abierto', 'cerrado')", name: "conteos_estado"

    create_table :conteo_lineas do |t|
      t.references :conteo, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :sistema, precision: 12, scale: 3, null: false, default: 0
      t.decimal :escaneado, precision: 12, scale: 3, null: false, default: 0
      t.decimal :manual, precision: 12, scale: 3, null: false, default: 0
      t.decimal :diferencia, precision: 12, scale: 3
      t.integer :diferencia_centavos

      t.timestamps
    end
    add_index :conteo_lineas, [ :conteo_id, :producto_id ], unique: true

    create_table :conteo_etiquetas do |t|
      t.references :conteo, null: false, foreign_key: true
      t.references :etiqueta, null: false, foreign_key: true

      t.timestamps
    end
    add_index :conteo_etiquetas, [ :conteo_id, :etiqueta_id ], unique: true

    # Lo que se le cobra al cajero por faltantes de conteo.
    create_table :cargos do |t|
      t.references :usuario, null: false, foreign_key: true
      t.references :conteo, null: false, foreign_key: true
      t.integer :monto_centavos, null: false
      t.text :detalle
      t.string :estado, null: false, default: "pendiente"
      t.references :resuelto_por, foreign_key: { to_table: :usuarios }
      t.datetime :resuelto_en

      t.timestamps
    end
    add_check_constraint :cargos, "monto_centavos > 0", name: "cargos_monto"
    add_check_constraint :cargos, "estado IN ('pendiente', 'cobrado', 'perdonado')", name: "cargos_estado"
  end
end

class CreateCaja < ActiveRecord::Migration[8.1]
  def change
    # Efectivo máximo en la gaveta antes de obligar un retiro a la caja fuerte.
    add_column :sucursales, :limite_efectivo_centavos, :integer, null: false, default: 300_000

    # Corte de caja: se abre con fondo, acumula ventas, devoluciones y retiros, y se cierra contando.
    create_table :cortes do |t|
      t.string :folio, null: false
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :cerrado_por, foreign_key: { to_table: :usuarios }
      t.string :estado, null: false, default: "abierto"
      t.integer :fondo_centavos, null: false, default: 0
      t.integer :contado_centavos
      t.integer :esperado_centavos
      t.integer :diferencia_centavos
      t.datetime :abierto_en, null: false
      t.datetime :cerrado_en

      t.timestamps
    end
    add_index :cortes, :folio, unique: true
    add_index :cortes, [ :sucursal_id, :estado ]
    add_check_constraint :cortes, "estado IN ('abierto', 'cerrado')", name: "cortes_estado"
    add_check_constraint :cortes, "fondo_centavos >= 0", name: "cortes_fondo"

    create_table :retiros do |t|
      t.references :corte, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :autorizado_por, null: false, foreign_key: { to_table: :usuarios }
      t.integer :monto_centavos, null: false
      t.string :motivo, null: false

      t.timestamps
    end
    add_check_constraint :retiros, "monto_centavos > 0", name: "retiros_monto"

    create_table :ventas do |t|
      t.string :folio, null: false
      t.string :codigo, null: false, limit: 13
      t.string :clave, null: false
      t.references :sucursal, null: false, foreign_key: true
      t.references :corte, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.string :estado, null: false, default: "cobrada"
      t.integer :total_centavos, null: false
      t.integer :cambio_centavos, null: false, default: 0
      t.date :fecha_negocio, null: false

      t.timestamps
    end
    add_index :ventas, :folio, unique: true
    add_index :ventas, :codigo, unique: true
    add_index :ventas, :clave, unique: true
    add_index :ventas, [ :corte_id, :estado ]
    add_check_constraint :ventas, "estado IN ('cobrada', 'devuelta')", name: "ventas_estado"
    add_check_constraint :ventas, "total_centavos >= 0", name: "ventas_total"

    create_table :venta_lineas do |t|
      t.references :venta, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.references :etiqueta, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.integer :precio_centavos, null: false
      t.integer :catalogo_centavos, null: false
      t.integer :importe_centavos, null: false
      t.references :autorizado_por, foreign_key: { to_table: :usuarios }

      t.timestamps
    end
    add_check_constraint :venta_lineas, "cantidad > 0", name: "venta_lineas_cantidad"
    add_check_constraint :venta_lineas, "precio_centavos >= 0 AND importe_centavos >= 0", name: "venta_lineas_dinero"

    create_table :pagos do |t|
      t.references :venta, null: false, foreign_key: true
      t.string :forma, null: false
      t.integer :monto_centavos, null: false

      t.timestamps
    end
    add_check_constraint :pagos, "forma IN ('efectivo', 'transferencia', 'deposito')", name: "pagos_forma"
    add_check_constraint :pagos, "monto_centavos > 0", name: "pagos_monto"

    create_table :devoluciones do |t|
      t.string :folio, null: false
      t.references :venta, null: false, foreign_key: true
      t.references :corte, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.string :motivo, null: false
      t.integer :total_centavos, null: false

      t.timestamps
    end
    add_index :devoluciones, :folio, unique: true

    create_table :devolucion_lineas do |t|
      t.references :devolucion, null: false, foreign_key: true
      t.references :venta_linea, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.integer :importe_centavos, null: false

      t.timestamps
    end
    add_check_constraint :devolucion_lineas, "cantidad > 0", name: "devolucion_lineas_cantidad"
  end
end

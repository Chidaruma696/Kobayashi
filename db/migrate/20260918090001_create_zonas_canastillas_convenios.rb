class CreateZonasCanastillasConvenios < ActiveRecord::Migration[8.1]
  def up
    # Zonas dentro de la ruta: el orden de reparto es zona → cliente.
    create_table :zonas do |t|
      t.references :ruta, null: false, foreign_key: true
      t.string :nombre, null: false
      t.integer :orden, null: false, default: 0
      t.boolean :activa, null: false, default: true

      t.timestamps
    end
    add_reference :clientes, :zona, foreign_key: true

    # Número de parada dentro del viaje: el orden de reparto que se genera al armarlo.
    add_column :salidas, :parada, :integer

    # Canastillas: activo prestado, con saldo por cliente y por chofer, por tipo (marca/color).
    create_table :tipos_canastilla do |t|
      t.string :nombre, null: false
      t.string :color
      t.boolean :activo, null: false, default: true

      t.timestamps
    end
    add_index :tipos_canastilla, :nombre, unique: true

    create_table :salida_canastillas do |t|
      t.references :salida, null: false, foreign_key: true
      t.references :tipo_canastilla, null: false, foreign_key: { to_table: :tipos_canastilla }
      t.integer :cantidad, null: false

      t.timestamps
    end
    add_index :salida_canastillas, [ :salida_id, :tipo_canastilla_id ], unique: true

    create_table :movimientos_canastillas do |t|
      t.references :cliente, foreign_key: true
      t.references :chofer, foreign_key: { to_table: :usuarios }
      t.references :viaje, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.references :tipo_canastilla, null: false, foreign_key: { to_table: :tipos_canastilla }
      t.string :tipo, null: false
      t.integer :cantidad_cliente, null: false, default: 0
      t.integer :cantidad_chofer, null: false, default: 0
      t.date :fecha, null: false
      t.string :concepto
      t.references :usuario, null: false, foreign_key: true

      t.timestamps
    end
    add_check_constraint :movimientos_canastillas, "tipo IN ('carga', 'entrega', 'devolucion', 'descarga', 'ajuste')", name: "movimientos_canastillas_tipo"

    # Convenio de precio: precio fijo por kg en ciertas líneas hasta un tope semanal de cajas.
    create_table :convenios do |t|
      t.references :cliente, null: false, foreign_key: true
      t.string :lineas, null: false
      t.string :excluir
      t.decimal :tope_cajas, precision: 8, scale: 2, null: false, default: 0
      t.integer :precio_centavos, null: false
      t.boolean :activo, null: false, default: true
      t.string :notas

      t.timestamps
    end
    add_index :convenios, :cliente_id, unique: true, where: "activo", name: "index_convenios_activo_por_cliente"
    add_reference :venta_lineas, :convenio, foreign_key: true
    add_column :venta_lineas, :convenio_cajas, :decimal, precision: 8, scale: 3, null: false, default: 0
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

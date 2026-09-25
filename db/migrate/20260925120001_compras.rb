# Módulo Compras: proveedores, recepción de mercancía (una entrada con proveedor), facturas del
# proveedor con renglones (el único sitio del precio de compra), ledger de deuda, pagos que salen de
# la gaveta, y el libro de envases del proveedor (canastilla, tarima, tote). Sin costo en inventario.
class Compras < ActiveRecord::Migration[8.1]
  def change
    create_table :proveedores do |t|
      t.string :nombre, null: false
      t.string :rfc
      t.string :contacto
      t.string :telefono
      t.integer :dias_credito, null: false, default: 0
      t.string :notas
      t.boolean :activo, null: false, default: true
      t.timestamps
    end
    add_index :proveedores, :nombre, unique: true

    create_table :facturas_proveedor do |t|
      t.references :proveedor, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.string :folio, null: false           # el del papel del proveedor
      t.date :fecha, null: false
      t.date :vence
      t.integer :monto_centavos, null: false, default: 0
      t.string :concepto
      t.string :estado, null: false, default: "abierta"
      t.string :motivo_cancelacion
      t.timestamps
    end
    add_index :facturas_proveedor, [ :proveedor_id, :folio ], unique: true
    add_check_constraint :facturas_proveedor, "estado IN ('abierta', 'cancelada')", name: "facturas_proveedor_estado"

    create_table :factura_proveedor_lineas do |t|
      t.references :factura_proveedor, null: false, foreign_key: { to_table: :facturas_proveedor }
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.integer :cajas, null: false, default: 0
      t.integer :precio_centavos, null: false
      t.integer :importe_centavos, null: false
      t.timestamps
    end

    create_table :recepciones do |t|
      t.references :sucursal, null: false, foreign_key: true
      t.references :proveedor, null: false, foreign_key: true
      t.references :factura_proveedor, foreign_key: { to_table: :facturas_proveedor }
      t.references :usuario, null: false, foreign_key: true
      t.string :folio, null: false
      t.string :remision
      t.date :fecha, null: false
      t.string :notas
      t.string :estado, null: false, default: "registrada"
      t.string :motivo_cancelacion
      t.integer :canastillas, null: false, default: 0
      t.integer :tarimas, null: false, default: 0
      t.integer :totes, null: false, default: 0
      t.string :clave                        # idempotencia desde el navegador
      t.timestamps
    end
    add_index :recepciones, [ :sucursal_id, :folio ], unique: true
    add_index :recepciones, [ :sucursal_id, :clave ], unique: true, where: "clave IS NOT NULL"
    add_check_constraint :recepciones, "estado IN ('registrada', 'cancelada')", name: "recepciones_estado"

    create_table :recepcion_lineas do |t|
      t.references :recepcion, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.integer :cajas, null: false, default: 0
      t.timestamps
    end

    create_table :pagos_proveedor do |t|
      t.references :proveedor, null: false, foreign_key: true
      t.references :factura_proveedor, foreign_key: { to_table: :facturas_proveedor }
      t.references :sucursal, null: false, foreign_key: true
      t.references :corte, foreign_key: true
      t.references :retiro, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :anulado_por, foreign_key: { to_table: :usuarios }
      t.integer :monto_centavos, null: false
      t.string :forma, null: false, default: "efectivo"
      t.string :referencia
      t.string :estado, null: false, default: "vigente"
      t.string :motivo_anulacion
      t.timestamps
    end
    add_check_constraint :pagos_proveedor, "estado IN ('vigente', 'anulado')", name: "pagos_proveedor_estado"

    create_table :movimientos_proveedor do |t|
      t.references :proveedor, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :factura_proveedor, foreign_key: { to_table: :facturas_proveedor }
      t.references :pago_proveedor, foreign_key: { to_table: :pagos_proveedor }
      t.string :tipo, null: false             # cargo | abono | ajuste
      t.integer :monto_centavos, null: false
      t.integer :delta_centavos, null: false  # con signo
      t.integer :saldo_centavos, null: false  # saldo corrido, informativo
      t.date :fecha, null: false
      t.string :concepto
      t.timestamps
    end
    add_check_constraint :movimientos_proveedor, "tipo IN ('cargo', 'abono', 'ajuste')", name: "movimientos_proveedor_tipo"

    create_table :envases_proveedor do |t|
      t.references :proveedor, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :recepcion, foreign_key: true
      t.string :envase, null: false           # canastilla | tarima | tote
      t.string :tipo, null: false             # entrada | devolucion | ajuste
      t.integer :cantidad, null: false
      t.integer :signo, null: false           # +1 entra y se lo debemos, -1 se devuelve
      t.integer :saldo, null: false
      t.date :fecha, null: false
      t.string :concepto
      t.timestamps
    end
    add_check_constraint :envases_proveedor, "envase IN ('canastilla', 'tarima', 'tote')", name: "envases_proveedor_envase"
  end
end

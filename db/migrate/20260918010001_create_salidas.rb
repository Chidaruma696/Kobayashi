class CreateSalidas < ActiveRecord::Migration[8.1]
  def change
    # Nota de salida: traspaso matriz → tienda, o devolución tienda → matriz. Se surte escaneando,
    # otra persona verifica la carga, se sella, se envía y el destino la recibe paquete por paquete.
    create_table :salidas do |t|
      t.string :folio, null: false
      t.string :tipo, null: false, default: "traspaso"
      t.references :sucursal_origen, null: false, foreign_key: { to_table: :sucursales }
      t.references :sucursal_destino, null: false, foreign_key: { to_table: :sucursales }
      t.references :usuario, null: false, foreign_key: true
      t.references :verificado_por, foreign_key: { to_table: :usuarios }
      t.string :estado, null: false, default: "preparando"
      t.string :motivo
      t.datetime :enviado_en
      t.datetime :recibido_en

      t.timestamps
    end
    add_index :salidas, :folio, unique: true
    add_index :salidas, [ :sucursal_origen_id, :estado ]
    add_index :salidas, [ :sucursal_destino_id, :estado ]
    add_check_constraint :salidas, "tipo IN ('traspaso', 'devolucion')", name: "salidas_tipo"
    add_check_constraint :salidas, "estado IN ('preparando', 'sellada', 'enviada', 'recibida', 'cancelada')", name: "salidas_estado"

    # Una fila por etiqueta HOJA (paquete o caja de proveedor) que viaja; `grupo` es la caja o
    # tarima que se escaneó al surtir, para verificar y recibir por grupo. Una etiqueta puede
    # viajar varias veces (ida y devolución), pero solo en una salida abierta o en tránsito a la vez.
    create_table :salida_etiquetas do |t|
      t.references :salida, null: false, foreign_key: true
      t.references :etiqueta, null: false, foreign_key: true
      t.references :grupo, foreign_key: { to_table: :etiquetas }
      t.references :verificado_por, foreign_key: { to_table: :usuarios }
      t.string :estado, null: false, default: "pendiente"
      t.string :motivo
      t.datetime :recibido_en

      t.timestamps
    end
    add_index :salida_etiquetas, [ :salida_id, :estado ]
    add_check_constraint :salida_etiquetas, "estado IN ('pendiente', 'recibida', 'faltante')", name: "salida_etiquetas_estado"

    # Renglones sin etiqueta (devolución manual justificada): producto y cantidad.
    create_table :salida_lineas do |t|
      t.references :salida, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.string :motivo, null: false
      t.references :autorizado_por, null: false, foreign_key: { to_table: :usuarios }
      t.boolean :recibida, null: false, default: false

      t.timestamps
    end
    add_check_constraint :salida_lineas, "cantidad > 0", name: "salida_lineas_cantidad"
  end
end

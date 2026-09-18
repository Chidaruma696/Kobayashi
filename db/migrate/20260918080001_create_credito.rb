class CreateCredito < ActiveRecord::Migration[8.1]
  def up
    # Crédito de ruta por tipo, como lo maneja el negocio. El punto de venta sigue siendo de contado.
    add_column :clientes, :credito, :string, null: false, default: "contado"
    add_column :clientes, :limite_credito_centavos, :integer, null: false, default: 0
    add_column :clientes, :dia_corte, :integer
    add_column :clientes, :bloqueo_manual, :string
    add_column :clientes, :bloqueo_motivo, :string
    add_reference :clientes, :bloqueo_por, foreign_key: { to_table: :usuarios }
    add_check_constraint :clientes, "credito IN ('contado', 'nota_x_nota', 'limite', 'semanal', 'contado_abonando', 'especial')", name: "clientes_credito"

    # La cuenta del cliente: cargos (+) por notas a crédito, abonos y devoluciones (−), ajustes (±).
    # El saldo es la suma; no hay acumulado que se desincronice.
    create_table :movimientos_credito do |t|
      t.references :cliente, null: false, foreign_key: true
      t.string :tipo, null: false
      t.integer :monto_centavos, null: false
      t.date :fecha, null: false
      t.references :referencia, polymorphic: true
      t.references :usuario, null: false, foreign_key: true
      t.string :motivo

      t.timestamps
    end
    add_index :movimientos_credito, [ :cliente_id, :fecha ]
    add_check_constraint :movimientos_credito, "tipo IN ('cargo', 'abono', 'devolucion', 'ajuste')", name: "movimientos_credito_tipo"

    # Un abono: en oficina entra a la caja abierta; en ruta lo trae el chofer hasta liquidar.
    create_table :abonos do |t|
      t.string :folio, null: false
      t.references :cliente, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.integer :monto_centavos, null: false
      t.string :forma, null: false
      t.references :usuario, null: false, foreign_key: true
      t.references :viaje, foreign_key: true
      t.references :corte, foreign_key: true
      t.boolean :en_ruta, null: false, default: false
      t.string :notas

      t.timestamps
    end
    add_index :abonos, :folio, unique: true
    add_check_constraint :abonos, "monto_centavos > 0", name: "abonos_monto"

    # Una venta cobrada o a crédito en la ruta no está en la gaveta hasta liquidar: es una marca, no un estado.
    add_column :ventas, :en_ruta, :boolean, null: false, default: false
    execute "UPDATE ventas SET estado = 'cobrada', en_ruta = 1 WHERE estado = 'cobrada_en_ruta'"
    remove_check_constraint :ventas, name: "ventas_estado"
    add_check_constraint :ventas, "estado IN ('por_cobrar', 'cobrada', 'a_credito', 'devuelta')", name: "ventas_estado"

    # Un renglón sin etiqueta también se puede rechazar en la parada.
    add_column :salida_lineas, :rechazada, :boolean, null: false, default: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

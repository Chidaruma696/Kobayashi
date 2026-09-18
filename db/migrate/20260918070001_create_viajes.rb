class CreateViajes < ActiveRecord::Migration[8.1]
  def up
    # Un viaje: la ruta de un día con su chofer y sus repartos, desde que sale hasta que liquida.
    create_table :viajes do |t|
      t.string :folio, null: false
      t.references :sucursal, null: false, foreign_key: true
      t.references :ruta, null: false, foreign_key: true
      t.references :chofer, null: false, foreign_key: { to_table: :usuarios }
      t.references :usuario, null: false, foreign_key: true
      t.date :fecha, null: false
      t.string :estado, null: false, default: "armando"
      t.datetime :salido_en
      t.datetime :liquidado_en
      t.references :liquidado_por, foreign_key: { to_table: :usuarios }
      t.integer :efectivo_esperado_centavos
      t.integer :efectivo_entregado_centavos
      t.integer :diferencia_centavos
      t.text :notas

      t.timestamps
    end
    add_index :viajes, :folio, unique: true
    add_check_constraint :viajes, "estado IN ('armando', 'en_ruta', 'liquidado', 'cancelado')", name: "viajes_estado"

    # Gastos del chofer en la ruta (gasolina, casetas…): salen del efectivo que trae.
    create_table :viaje_gastos do |t|
      t.references :viaje, null: false, foreign_key: true
      t.string :concepto, null: false
      t.integer :monto_centavos, null: false
      t.references :usuario, null: false, foreign_key: true

      t.timestamps
    end
    add_check_constraint :viaje_gastos, "monto_centavos > 0", name: "viaje_gastos_monto"

    add_reference :salidas, :viaje, foreign_key: true
    remove_check_constraint :salidas, name: "salidas_estado"
    add_check_constraint :salidas, "estado IN ('preparando', 'sellada', 'enviada', 'recibida', 'entregada', 'rechazada', 'cancelada')", name: "salidas_estado"

    # Cobrada en ruta: el chofer ya tiene el dinero, pero entra a la caja hasta liquidar.
    remove_check_constraint :ventas, name: "ventas_estado"
    add_check_constraint :ventas, "estado IN ('por_cobrar', 'cobrada_en_ruta', 'cobrada', 'devuelta')", name: "ventas_estado"

    # Un rechazo en ruta es una devolución sin dinero de por medio: no lleva corte.
    change_column_null :devoluciones, :corte_id, true
    add_reference :devoluciones, :sucursal, foreign_key: true
    execute "UPDATE devoluciones SET sucursal_id = (SELECT sucursal_id FROM cortes WHERE cortes.id = devoluciones.corte_id)"
    change_column_null :devoluciones, :sucursal_id, false

    add_reference :cargos, :viaje, foreign_key: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

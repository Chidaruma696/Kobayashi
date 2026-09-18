class CreateRevisiones < ActiveRecord::Migration[8.1]
  def up
    # Autorización diferida: lo que se hizo sin quien lo autorizara al momento queda aquí,
    # a nombre de quien lo hizo y con su motivo, para que el supervisor lo revise después.
    create_table :revisiones do |t|
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.references :revisable, polymorphic: true, null: false
      t.string :motivo, null: false
      t.integer :valor_centavos, null: false, default: 0
      t.string :estado, null: false, default: "pendiente"
      t.references :revisado_por, foreign_key: { to_table: :usuarios }
      t.datetime :revisado_en
      t.string :nota

      t.timestamps
    end
    add_index :revisiones, [ :sucursal_id, :estado ]
    add_check_constraint :revisiones, "estado IN ('pendiente', 'aprobada', 'observada')", name: "revisiones_estado"

    # Un cargo ya no nace solo de un conteo: también de una revisión observada.
    add_reference :cargos, :sucursal, foreign_key: true
    execute "UPDATE cargos SET sucursal_id = (SELECT sucursal_id FROM conteos WHERE conteos.id = cargos.conteo_id)"
    change_column_null :cargos, :sucursal_id, false
    change_column_null :cargos, :conteo_id, true
    add_reference :cargos, :revision, foreign_key: { to_table: :revisiones }

    # Lo que antes exigía autorizador ahora puede quedar por revisar.
    change_column_null :salida_lineas, :autorizado_por_id, true
    add_reference :salida_lineas, :usuario, foreign_key: true
    change_column_null :retiros, :autorizado_por_id, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

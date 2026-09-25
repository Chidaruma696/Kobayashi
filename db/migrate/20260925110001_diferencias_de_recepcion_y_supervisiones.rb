# #14: la salida guarda el canto de la recepción por caja. #15: supervisión, un conteo que solo
# revisa (qué etiquetas se vieron y qué pesadas no encontraron pareja) y nunca ajusta nada.
class DiferenciasDeRecepcionYSupervisiones < ActiveRecord::Migration[8.1]
  def change
    add_column :salidas, :diferencias, :text

    create_table :supervisiones do |t|
      t.references :sucursal, null: false, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.string :folio, null: false
      t.string :estado, null: false, default: "abierta"
      t.string :notas
      t.datetime :cerrado_en
      t.timestamps
    end
    add_index :supervisiones, [ :sucursal_id, :folio ], unique: true
    add_check_constraint :supervisiones, "estado IN ('abierta', 'cerrada')", name: "supervisiones_estado"

    create_table :supervision_etiquetas do |t|
      t.references :supervision, null: false, foreign_key: { to_table: :supervisiones }
      t.references :etiqueta, foreign_key: true
      t.references :usuario, null: false, foreign_key: true
      t.string :como, null: false, default: "escaneo"   # escaneo | pesada
      t.decimal :cantidad, precision: 12, scale: 3        # lo que marcó la báscula, cuando fue pesada
      t.timestamps
    end
    add_index :supervision_etiquetas, [ :supervision_id, :etiqueta_id ], unique: true, where: "etiqueta_id IS NOT NULL"
  end
end

# Almacén externo (sucursal tipo "almacen": frigorífico ajeno donde la mercancía solo se guarda a
# granel) y traspasos a granel: kilos y cajas que cambian de sucursal sin escanear etiqueta por
# etiqueta. El traspaso deja dos renglones de kardex (sale y entra) en la misma transacción.
class TraspasosAGranel < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        remove_check_constraint :sucursales, name: "sucursales_tipo"
        add_check_constraint :sucursales, "tipo IN ('matriz', 'tienda', 'almacen')", name: "sucursales_tipo"
      end
      dir.down do
        remove_check_constraint :sucursales, name: "sucursales_tipo"
        add_check_constraint :sucursales, "tipo IN ('matriz', 'tienda')", name: "sucursales_tipo"
      end
    end

    create_table :traspasos do |t|
      t.references :sucursal_origen, null: false, foreign_key: { to_table: :sucursales }
      t.references :sucursal_destino, null: false, foreign_key: { to_table: :sucursales }
      t.references :usuario, null: false, foreign_key: true
      t.string :folio, null: false
      t.date :fecha, null: false
      t.string :notas
      t.string :estado, null: false, default: "registrado"
      t.string :motivo_cancelacion
      t.string :clave
      t.timestamps
    end
    add_index :traspasos, [ :sucursal_origen_id, :folio ], unique: true
    add_index :traspasos, [ :sucursal_origen_id, :clave ], unique: true, where: "clave IS NOT NULL"
    add_check_constraint :traspasos, "estado IN ('registrado', 'cancelado')", name: "traspasos_estado"

    create_table :traspaso_lineas do |t|
      t.references :traspaso, null: false, foreign_key: true
      t.references :producto, null: false, foreign_key: true
      t.decimal :cantidad, precision: 12, scale: 3, null: false
      t.integer :cajas, null: false, default: 0
      t.integer :etiquetas_bajadas, null: false, default: 0
      t.timestamps
    end
  end
end
